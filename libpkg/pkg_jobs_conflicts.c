/*-
 * Copyright (c) 2014 Vsevolod Stakhov <vsevolod@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer
 *    in this position and unchanged.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <sys/param.h>
#include <sys/types.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#ifdef HAVE_ARC4RANDOM
#include <time.h>
#endif

#include "pkg.h"
#include "private/event.h"
#include "private/pkg.h"
#include "private/pkgdb.h"
#include "private/pkg_jobs.h"
#include "siphash.h"

struct pkg_conflict_chain {
	struct pkg_job_request *req;
	struct pkg_conflict_chain *next;
};


static struct sipkey *
pkg_conflicts_sipkey_init(void)
{
	static struct sipkey *kinit;

	if (kinit == NULL) {
		kinit = xmalloc(sizeof(*kinit));
#ifdef HAVE_ARC4RANDOM
		arc4random_buf((unsigned char*)kinit, sizeof(*kinit));
#else
		srand((unsigned int) time(NULL));
		for (size_t i = 0; i < sizeof(*kinit); i++)
			*(int *)(kinit + i) = rand();
#endif
	}

	return (kinit);
}

static int
pkg_conflicts_chain_cmp_cb(struct pkg_conflict_chain *a, struct pkg_conflict_chain *b)
{
	const char *vera, *verb;

	if (a->req->skip || b->req->skip) {
		return (a->req->skip - b->req->skip);
	}

	vera = a->req->item->pkg->version;
	verb = b->req->item->pkg->version;

	/* Inverse sort to get the maximum version as the first element */
	return (pkg_version_cmp(vera, verb));
}

static int
pkg_conflicts_request_resolve_chain(struct pkg *req, struct pkg_conflict_chain *chain)
{
	struct pkg_conflict_chain *elt, *selected = NULL;
	const char *slash_pos;

	/*
	 * First of all prefer pure origins, where the last element of
	 * an origin is pkg name
	 */
	LL_FOREACH(chain, elt) {
		slash_pos = strrchr(elt->req->item->pkg->origin, '/');
		if (slash_pos != NULL) {
			if (strcmp(slash_pos + 1, req->name) == 0) {
				selected = elt;
				break;
			}
		}
	}

	if (selected == NULL) {
		/* XXX: add manual selection here */
		/* Sort list by version of package */
		LL_SORT(chain, pkg_conflicts_chain_cmp_cb);
		selected = chain;
	}

	pkg_debug(2, "select %s in the chain of conflicts for %s",
	    selected->req->item->pkg->name, req->name);
	/* Disable conflicts from a request */
	LL_FOREACH(chain, elt) {
		if (elt != selected)
			elt->req->skip = true;
	}

	return (EPKG_OK);
}

static void
pkg_conflicts_request_add_chain(struct pkg_conflict_chain **chain, struct pkg_job_request *req)
{
	struct pkg_conflict_chain *elt;

	elt = xcalloc(1, sizeof(struct pkg_conflict_chain));
	elt->req = req;
	LL_PREPEND(*chain, elt);
}

int
pkg_conflicts_request_resolve(struct pkg_jobs *j)
{
	struct pkg_job_request *req, *rtmp, *found;
	struct pkg_conflict *c;
	struct pkg_conflict_chain *chain;
	struct pkg_job_universe_item *unit;

	HASH_ITER(hh, j->request_add, req, rtmp) {
		chain = NULL;
		if (req->skip)
			continue;

		LL_FOREACH(req->item->pkg->conflicts, c) {
			unit = pkg_jobs_universe_find(j->universe, c->uid);
			if (unit != NULL) {
				HASH_FIND_STR(j->request_add, unit->pkg->uid, found);
				if (found && !found->skip) {
					pkg_conflicts_request_add_chain(&chain, found);
				}
			}
		}
		if (chain != NULL) {
			/* Add package itself */
			pkg_conflicts_request_add_chain(&chain, req);

			if (pkg_conflicts_request_resolve_chain(req->item->pkg, chain) != EPKG_OK) {
				LL_FREE(chain, free);
				return (EPKG_FATAL);
			}
			LL_FREE(chain, free);
		}
	}

	return (EPKG_OK);
}

void
pkg_conflicts_register(struct pkg *p1, struct pkg *p2, enum pkg_conflict_type type)
{
	struct pkg_conflict *c1, *c2;

	c1 = xcalloc(1, sizeof(*c1));
	c2 = xcalloc(1, sizeof(*c2));

	c1->type = c2->type = type;
	if (!kh_contains(pkg_conflicts, p1->conflictshash, p2->uid)) {
		c1->uid = xstrdup(p2->uid);
		kh_safe_add(pkg_conflicts, p1->conflictshash, c1, c1->uid);
		DL_APPEND(p1->conflicts, c1);
		pkg_debug(2, "registering conflict between %s(%s) and %s(%s)",
				p1->uid, p1->type == PKG_INSTALLED ? "l" : "r",
				p2->uid, p2->type == PKG_INSTALLED ? "l" : "r");
	} else {
		pkg_conflict_free(c1);
	}

	if (!kh_contains(pkg_conflicts, p2->conflictshash, p1->uid)) {
		c2->uid = xstrdup(p1->uid);
		kh_safe_add(pkg_conflicts, p2->conflictshash, c2, c2->uid);
		DL_APPEND(p2->conflicts, c2);
		pkg_debug(2, "registering conflict between %s(%s) and %s(%s)",
				p2->uid, p2->type == PKG_INSTALLED ? "l" : "r",
				p1->uid, p1->type == PKG_INSTALLED ? "l" : "r");
	} else {
		pkg_conflict_free(c2);
	}
}



static int
pkg_conflicts_item_cmp(struct avl_node *a, struct avl_node *b, void *aux __unused)
{
	struct pkg_jobs_conflict_item *aa, *bb;

	aa = avl_get_entry(a, struct pkg_jobs_conflict_item, avl);
	bb = avl_get_entry(b, struct pkg_jobs_conflict_item, avl);

	return ((bb->hash > aa->hash) - (aa->hash > bb->hash));
}

/*
 * Checks whether we need to add a conflict between two packages
 */
static bool
pkg_conflicts_need_conflict(struct pkg_jobs *j, struct pkg *p1, struct pkg *p2)
{
	struct pkg_file *fcur;

	if (pkgdb_ensure_loaded(j->db, p1, PKG_LOAD_FILES|PKG_LOAD_DIRS) != EPKG_OK ||
			pkgdb_ensure_loaded(j->db, p2, PKG_LOAD_FILES|PKG_LOAD_DIRS)
						!= EPKG_OK) {
		/*
		 * If some of packages are not loaded we could silently and safely
		 * ignore them
		 */
		pkg_debug(1, "cannot load files from %s and %s to check conflicts",
			p1->name, p2->name);

		return (false);
	}

	/*
	 * Check if we already have this conflict registered
	 */
	if (kh_contains(pkg_conflicts, p1->conflictshash, p2->uid) &&
	    kh_contains(pkg_conflicts, p2->conflictshash, p1->uid))
		return false;

	/*
	 * We need to check all files and dirs and find the similar ones
	 */
	LL_FOREACH(p1->files, fcur) {
		if (pkg_has_file(p2, fcur->path))
			return (true);
		if (pkg_has_dir(p2, fcur->path))
			return (true);
	}
	/* XXX pkg dirs are terribly broken */

	/* No common paths are found in p1 and p2 */
	return (false);
}

/*
 * Just insert new conflicts items to the packages
 */
static void
pkg_conflicts_register_unsafe(struct pkg *p1, struct pkg *p2,
	const char *path,
	enum pkg_conflict_type type,
	bool use_digest)
{
	struct pkg_conflict *c1, *c2;

	kh_find(pkg_conflicts, p1->conflictshash, p2->uid, c1);
	kh_find(pkg_conflicts, p2->conflictshash, p1->uid, c2);
	if (c1 == NULL) {
		c1 = xcalloc(1, sizeof(*c1));
		c1->type = type;
		c1->uid = xstrdup(p2->uid);

		if (use_digest) {
			c1->digest = xstrdup(p2->digest);
		}

		kh_safe_add(pkg_conflicts, p1->conflictshash, c1, c1->uid);
		DL_APPEND(p1->conflicts, c1);
	}

	if (c2 == NULL) {
		c2 = xcalloc(1, sizeof(*c2));
		c2->type = type;

		c2->uid = xstrdup(p1->uid);

		if (use_digest) {
			/* We also add digest information into account */

			c2->digest = xstrdup(p1->digest);
		}

		kh_safe_add(pkg_conflicts, p2->conflictshash, c2, c2->uid);
		DL_APPEND(p2->conflicts, c2);
	}

	pkg_debug(2, "registering conflict between %s(%s) and %s(%s) on path %s",
			p1->uid, p1->type == PKG_INSTALLED ? "l" : "r",
			p2->uid, p2->type == PKG_INSTALLED ? "l" : "r", path);
}

/*
 * Register conflicts between packages in the universe chains
 */
static bool
pkg_conflicts_register_chain(struct pkg_jobs *j, struct pkg_job_universe_item *u1,
	struct pkg_job_universe_item *u2, const char *path)
{
	struct pkg_job_universe_item *cur1, *cur2;
	bool ret = false;

	cur1 = u1;

	do {

		cur2 = u2;
		do {
			struct pkg *p1 = cur1->pkg, *p2 = cur2->pkg;

			if (p1->type == PKG_INSTALLED && p2->type == PKG_INSTALLED) {
				/* Local and local packages cannot conflict */
				cur2 = cur2->prev;
				continue;
			}
			else if (p1->type == PKG_INSTALLED || p2->type == PKG_INSTALLED) {
				/* local <-> remote conflict */
				if (pkg_conflicts_need_conflict(j, p1, p2)) {
					pkg_emit_conflicts(p1, p2, path);
					pkg_conflicts_register_unsafe(p1, p2, path,
						PKG_CONFLICT_REMOTE_LOCAL, true);
					j->conflicts_registered ++;
					ret = true;
				}
			}
			else {
				/* two remote packages */
				if (pkg_conflicts_need_conflict(j, p1, p2)) {
					pkg_emit_conflicts(p1, p2, path);
					pkg_conflicts_register_unsafe(p1, p2, path,
						PKG_CONFLICT_REMOTE_REMOTE, true);
					j->conflicts_registered ++;
					ret = true;
				}
			}
			cur2 = cur2->prev;
		} while (cur2 != u2);

		cur1 = cur1->prev;
	} while (cur1 != u1);

	return (ret);
}

/*
 * Check whether the specified path is registered locally and returns
 * the package that contains that path or NULL if no conflict was found
 */
static struct pkg *
pkg_conflicts_check_local_path(const char *path, const char *uid,
	struct pkg_jobs *j)
{
	const char sql_local_conflict[] = ""
		"SELECT p.name as uniqueid FROM packages AS p "
		"INNER JOIN files AS f "
		"ON p.id = f.package_id "
		"WHERE f.path = ?1;";
	sqlite3_stmt *stmt;
	int ret;
	struct pkg *p = NULL;

	pkg_debug(4, "Pkgdb: running '%s'", sql_local_conflict);
	ret = sqlite3_prepare_v2(j->db->sqlite, sql_local_conflict, -1,
		&stmt, NULL);
	if (ret != SQLITE_OK) {
		ERROR_SQLITE(j->db->sqlite, sql_local_conflict);
		return (NULL);
	}

	sqlite3_bind_text(stmt, 1,
		path, -1, SQLITE_STATIC);
	sqlite3_bind_text(stmt, 2,
		uid, -1, SQLITE_STATIC);

	if (sqlite3_step(stmt) == SQLITE_ROW) {
		/*
		 * We have found the conflict with some other chain, so find that chain
		 * or update the universe
		 */
		const char *uid_local = sqlite3_column_text(stmt, 0);

		p = pkg_jobs_universe_get_local(j->universe,
			uid_local, 0);
		assert(p != NULL);

		assert(strcmp(uid, p->uid) != 0);

		if (!kh_contains(pkg_conflicts, p->conflictshash, uid)) {
			/* We need to register the conflict between two universe chains */
			sqlite3_finalize(stmt);
			return (p);
		}
	}

	sqlite3_finalize(stmt);
	return (NULL);
}

static struct pkg_job_universe_item *
pkg_conflicts_check_all_paths(struct pkg_jobs *j, const char *path,
	struct pkg_job_universe_item *it, struct sipkey *k)
{
	const char *uid1, *uid2;
	struct pkg_jobs_conflict_item *cit, test;
	struct pkg_conflict *c;
	struct avl_node *cursor;
	uint64_t hv;

	hv = siphash24(path, strlen(path), k);
	test.hash = hv;
	cursor = avl_search(j->conflict_items, &test.avl, pkg_conflicts_item_cmp);
	cit = avl_get_entry(cursor, struct pkg_jobs_conflict_item, avl);

	if (cit == NULL) {
		/* New entry */
		cit = xcalloc(1, sizeof(*cit));
		cit->hash = hv;
		cit->item = it;
		avl_insert(j->conflict_items, &cit->avl, pkg_conflicts_item_cmp);
	}
	else {
		/* Check the same package */
		if (cit->item == it)
			return (NULL);

		uid1 = it->pkg->uid;
		uid2 = cit->item->pkg->uid;
		if (strcmp(uid1, uid2) == 0) {
			/* The same upgrade chain, just upgrade item for speed */
			cit->item = it;
			return (NULL);
		}

		/* Here we can have either collision or a real conflict */
		kh_find(pkg_conflicts, it->pkg->conflictshash, uid2, c);
		if (c != NULL || !pkg_conflicts_register_chain(j, it, cit->item, path)) {
			/*
			 * Collision found, change the key following the
			 * Cuckoo principle
			 */
			struct sipkey nk;

			pkg_debug(2, "found a collision on path %s between %s and %s, key: %lu",
				path, uid1, uid2, (unsigned long)k->k[0]);

			nk = *k;
			nk.k[0] ++;
			return (pkg_conflicts_check_all_paths(j, path, it, &nk));
		}

		return (cit->item);
	}

	return (NULL);
}

static void
pkg_conflicts_check_chain_conflict(struct pkg_job_universe_item *it,
	struct pkg_job_universe_item *local, struct pkg_jobs *j)
{
	struct pkg_file *fcur;
	struct pkg *p;
	struct pkg_job_universe_item *cun;
	struct sipkey *k;

	LL_FOREACH(it->pkg->files, fcur) {
		k = pkg_conflicts_sipkey_init();
		/* Check in hash tree */
		cun = pkg_conflicts_check_all_paths(j, fcur->path, it, k);

		if (local != NULL) {
			/* Filter only new files for remote packages */
			if (pkg_has_file(local->pkg, fcur->path))
				continue;
		}
		/* Check for local conflict in db */
		p = pkg_conflicts_check_local_path(fcur->path, it->pkg->uid, j);
		pkg_debug(4, "integrity: check path %s of package %s", fcur->path,
			it->pkg->uid);

		if (p != NULL) {
			if (pkg_jobs_universe_process_item(j->universe, p, &cun))
				continue;
			assert(cun != NULL);
			pkg_conflicts_register_chain(j, it, cun, fcur->path);
		}
	}
	/* XXX: dirs are currently broken terribly */
#if 0
	struct pkg_dir *dcur, *dtmp, *df;
	HASH_ITER(hh, it->pkg->dirs, dcur, dtmp) {
		memset(&k, 0, sizeof(k));
		cun = pkg_conflicts_check_all_paths(j, dcur->path, it, &k);

		if (local != NULL) {
			HASH_FIND_STR(local->pkg->dirs, dcur->path, df);
			if (df != NULL)
				continue;
		}
		/* Check for local conflict in db */
		p = pkg_conflicts_check_local_path(dcur->path, uid, j);
		if (p != NULL) {
			pkg_jobs_universe_process_item(j->universe, p, &cun);
			assert(cun != NULL);
			pkg_conflicts_register_chain(j, it, cun, dcur->path);
		}
	}
#endif
}

int
pkg_conflicts_append_chain(struct pkg_job_universe_item *it,
	struct pkg_jobs *j)
{
	struct pkg_job_universe_item *lp = NULL, *cur;

	/* Ensure that we have a tree initialized */
	if (j->conflict_items == NULL) {
		j->conflict_items = xmalloc(sizeof(*j->conflict_items));
		avl_init(j->conflict_items, NULL);
	}
	/* Find local package */
	cur = it->prev;
	while (cur != it) {
		if (cur->pkg->type == PKG_INSTALLED) {
			lp = cur;
			if (pkgdb_ensure_loaded(j->db, cur->pkg, PKG_LOAD_FILES|PKG_LOAD_DIRS)
							!= EPKG_OK)
				return (EPKG_FATAL);

			/* Local package is found */
			break;
		}
		cur = cur->prev;
	}

	/*
	 * Now we go through the all packages in the chain and check them against
	 * conflicts with the locally installed files
	 */
	cur = it;
	do {
		if (cur != lp) {
			if (pkgdb_ensure_loaded(j->db, cur->pkg, PKG_LOAD_FILES|PKG_LOAD_DIRS)
							!= EPKG_OK) {
				/*
				 * This means that a package was not downloaded, so we can safely
				 * ignore this conflict, since we are not going to install it
				 * anyway
				 */
				pkg_debug (3, "cannot load files from %s to check integrity",
					cur->pkg->name);
			}
			else {
				pkg_conflicts_check_chain_conflict(cur, lp, j);
			}
		}

		cur = cur->prev;
	} while (cur != it);

	return (EPKG_OK);
}
