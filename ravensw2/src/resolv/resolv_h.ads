--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

with Interfaces.C.Strings;

package resolv_h is

   package IC  renames Interfaces.C;
   package ICS renames Interfaces.C.Strings;


   type ns_class is
     (ns_c_invalid,
      ns_c_in,
      ns_c_2,
      ns_c_chaos,
      ns_c_hs,
      ns_c_none,
      ns_c_any,
      ns_c_max);
   pragma Convention (C, ns_class);
   for ns_class use
     (ns_c_invalid => 0,
      ns_c_in      => 1,
      ns_c_2       => 2,
      ns_c_chaos   => 3,
      ns_c_hs      => 4,
      ns_c_none    => 254,
      ns_c_any     => 255,
      ns_c_max     => 65536);

   type ns_type is
     (ns_t_invalid,
      ns_t_a,
      ns_t_ns,
      ns_t_md,
      ns_t_mf,
      ns_t_cname,
      ns_t_soa,
      ns_t_mb,
      ns_t_mg,
      ns_t_mr,
      ns_t_null,
      ns_t_wks,
      ns_t_ptr,
      ns_t_hinfo,
      ns_t_minfo,
      ns_t_mx,
      ns_t_txt,
      ns_t_rp,
      ns_t_afsdb,
      ns_t_x25,
      ns_t_isdn,
      ns_t_rt,
      ns_t_nsap,
      ns_t_nsap_ptr,
      ns_t_sig,
      ns_t_key,
      ns_t_px,
      ns_t_gpos,
      ns_t_aaaa,
      ns_t_loc,
      ns_t_nxt,
      ns_t_eid,
      ns_t_nimloc,
      ns_t_srv,
      ns_t_atma,
      ns_t_naptr,
      ns_t_kx,
      ns_t_cert,
      ns_t_a6,
      ns_t_dname,
      ns_t_sink,
      ns_t_opt,
      ns_t_apl,
      ns_t_ds,
      ns_t_sshfp,
      ns_t_ipseckey,
      ns_t_rrsig,
      ns_t_nsec,
      ns_t_dnskey,
      ns_t_dhcid,
      ns_t_nsec3,
      ns_t_nsec3param,
      ns_t_hip,
      ns_t_spf,
      ns_t_tkey,
      ns_t_tsig,
      ns_t_ixfr,
      ns_t_axfr,
      ns_t_mailb,
      ns_t_maila,
      ns_t_any,
      ns_t_zxfr,
      ns_t_dlv,
      ns_t_max);
   pragma Convention (C, ns_type);
   for ns_type use
     (ns_t_invalid => 0,       --  < Cookie. */
      ns_t_a => 1,             --  < Host address. */
      ns_t_ns => 2,            --  < Authoritative server. */
      ns_t_md => 3,            --  < Mail destination. */
      ns_t_mf => 4,            --  < Mail forwarder. */
      ns_t_cname => 5,         --  < Canonical name. */
      ns_t_soa => 6,           --  < Start of authority zone. */
      ns_t_mb => 7,            --  < Mailbox domain name. */
      ns_t_mg => 8,            --  < Mail group member. */
      ns_t_mr => 9,            --  < Mail rename name. */
      ns_t_null => 10,         --  < Null resource record. */
      ns_t_wks => 11,          --  < Well known service. */
      ns_t_ptr => 12,          --  < Domain name pointer. */
      ns_t_hinfo => 13,        --  < Host information. */
      ns_t_minfo => 14,        --  < Mailbox information. */
      ns_t_mx => 15,           --  < Mail routing information. */
      ns_t_txt => 16,          --  < Text strings. */
      ns_t_rp => 17,           --  < Responsible person. */
      ns_t_afsdb => 18,        --  < AFS cell database. */
      ns_t_x25 => 19,          --  < X_25 calling address. */
      ns_t_isdn => 20,         --  < ISDN calling address. */
      ns_t_rt => 21,           --  < Router. */
      ns_t_nsap => 22,         --  < NSAP address. */
      ns_t_nsap_ptr => 23,     --  < Reverse NSAP lookup (deprecated). */
      ns_t_sig => 24,          --  Security signature.
      ns_t_key => 25,          --  < Security key. */
      ns_t_px => 26,           --  < X.400 mail mapping. */
      ns_t_gpos => 27,         --  < Geographical position (withdrawn). */
      ns_t_aaaa => 28,         --  < IPv6 Address. */
      ns_t_loc => 29,          --  < Location Information. */
      ns_t_nxt => 30,          --  < Next domain (security). */
      ns_t_eid => 31,          --  < Endpoint identifier. */
      ns_t_nimloc => 32,       --  < Nimrod Locator. */
      ns_t_srv => 33,          --  < Server Selection. */
      ns_t_atma => 34,         --  < ATM Address */
      ns_t_naptr => 35,        --  < Naming Authority PoinTeR */
      ns_t_kx => 36,           --  < Key Exchange */
      ns_t_cert => 37,         --  < Certification record */
      ns_t_a6 => 38,           --  < IPv6 address (experimental) */
      ns_t_dname => 39,        --  < Non-terminal DNAME */
      ns_t_sink => 40,         --  < Kitchen sink (experimentatl) */
      ns_t_opt => 41,          --  < EDNS0 option (meta-RR) */
      ns_t_apl => 42,          --  < Address prefix list (RFC3123) */
      ns_t_ds => 43,           --  < Delegation Signer */
      ns_t_sshfp => 44,        --  < SSH Fingerprint */
      ns_t_ipseckey => 45,     --  < IPSEC Key */
      ns_t_rrsig => 46,        --  < RRset Signature */
      ns_t_nsec => 47,         --  < Negative security */
      ns_t_dnskey => 48,       --  < DNS Key */
      ns_t_dhcid => 49,        --  < Dynamic host configuratin identifier */
      ns_t_nsec3 => 50,        --  < Negative security type 3 */
      ns_t_nsec3param => 51,   --  < Negative security type 3 parameters */
      ns_t_hip => 55,          --  < Host Identity Protocol */
      ns_t_spf => 99,          --  < Sender Policy Framework */
      ns_t_tkey => 249,        --  < Transaction key */
      ns_t_tsig => 250,        --  < Transaction signature. */
      ns_t_ixfr => 251,        --  < Incremental zone transfer. */
      ns_t_axfr => 252,        --  < Transfer zone of authority. */
      ns_t_mailb => 253,       --  < Transfer mailbox records. */
      ns_t_maila => 254,       --  < Transfer mail agent records. */
      ns_t_any => 255,         --  < Wildcard match. */
      ns_t_zxfr => 256,        --  < BIND-specific, nonstandard. */
      ns_t_dlv => 32769,       --  < DNSSEC look-aside validatation. */
      ns_t_max => 65536);

   function C_res_query
     (dname  : IC.Strings.chars_ptr;
      rclass : ns_class;
      rtype  : ns_type;
      answer : access IC.char;
      anslen : IC.int) return IC.int;
   pragma Import (C, C_res_query, "__res_query");

   function C_dn_expand
     (msg     : access IC.char;
      eomorig : access IC.char;
      comp_dn : access IC.char;
      exp_dn  : access IC.char;
      length  : IC.int) return IC.int;
   pragma Import (C, C_dn_expand, "__dn_expand");

   function C_set_nameserver
     (nsname : IC.Strings.chars_ptr) return IC.int;
   pragma Import (C, C_set_nameserver, "set_nameserver");

end resolv_h;
