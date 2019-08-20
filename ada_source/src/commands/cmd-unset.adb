--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../License.txt

with Ada.Characters.Latin_1;
with Core.Pkg;     use Core.Pkg;
with Core.Strings; use Core.Strings;

package body Cmd.Unset is

   package LAT renames Ada.Characters.Latin_1;

   --------------------------------------------------------------------
   --  execute_no_command
   --------------------------------------------------------------------
   function execute_no_command (comline : Cldata) return Boolean
   is
      result : Pkg_Error_Type;
   begin
      if comline.glob_version = 1 then
         return basic_version_info;
      end if;
      if comline.glob_version = 2 then
         result := pkg_ini (path     => USS (comline.glob_config_file),
                            reposdir => USS (comline.glob_repo_config_dir),
                            flags    => comline.global_init_flags,
                            dlevel   => comline.glob_debug);
         return extended_version_info;
      end if;
      if comline.glob_list then
         return list_commands;
      end if;
      return True;
   end execute_no_command;


   --------------------------------------------------------------------
   --  basic_version_info
   --------------------------------------------------------------------
   function basic_version_info return Boolean is
   begin
      TIO.Put_Line (progversion);
      return True;
   end basic_version_info;


   --------------------------------------------------------------------
   --  extended_version_info
   --------------------------------------------------------------------
   function extended_version_info return Boolean is
   begin
      --  Don't pad with 24 characters like FreeBSD pkg, it looks weird.
      --  It must be a holdover from a previous design (pre-ucl?)
      TIO.Put_Line ("Version: " & progversion);
      TIO.Put_Line (pkg_config_dump);

      show_repository_info;

      return True;
   end extended_version_info;


   --------------------------------------------------------------------
   --  format_extconfig
   --------------------------------------------------------------------
   function format_extconfig (name, value : String; last : Boolean := False) return String
   is
      width     : constant Natural := 16;
      namespace : String (1 .. width) := (others => ' ');
      namelen   : Natural := name'Length;
   begin
      if namelen > width then
         namelen := width;
      end if;
      namespace (1 .. namelen) := name (name'First .. name'First + namelen - 1);
      if last then
         return namespace & ": " & LAT.Quotation & value & LAT.Quotation;
      else
         return namespace & ": " & LAT.Quotation & value & LAT.Quotation & LAT.Comma;
      end if;
   end format_extconfig;


   --------------------------------------------------------------------
   --  print_extconfig
   --------------------------------------------------------------------
   procedure print_extconfig (name, value : String; last : Boolean := False) is
   begin
      TIO.Put_Line (format_extconfig (name, value, last));
   end print_extconfig;


   --------------------------------------------------------------------
   --  list_command
   --------------------------------------------------------------------
   function list_commands return Boolean
   is
   begin
      for command in Command_verb'Range loop
         if command /= Command_verb'First then
            TIO.Put_Line (convert_command_enum_to_label (command));
         end if;
      end loop;
      return True;
   end list_commands;


   --------------------------------------------------------------------
   --  show_repository_info
   --------------------------------------------------------------------
   procedure show_repository_info is
      procedure list (position : pkg_repos_crate.Cursor);
      procedure list (position : pkg_repos_crate.Cursor)
      is
         repo : T_pkg_repo renames pkg_repos_crate.Element (position);
      begin
         TIO.Put_Line ("  " & USS (repo.name) & ": {");
         print_extconfig ("url", pkg_repo_name (repo));
         print_extconfig ("enabled", pkg_repo_enabled (repo));
         print_extconfig ("priority", pkg_repo_priority_type (repo));
         print_extconfig ("mirror_type", pkg_repo_mirror_type (repo));
         print_extconfig ("signature_type", pkg_repo_signature_type (repo));
         print_extconfig ("fingerprints", pkg_repo_fingerprints (repo));
         print_extconfig ("pubkey", pkg_repo_pubkey (repo));
         print_extconfig ("ip_version", pkg_repo_ipv_type (repo), True);
         TIO.Put_Line ("  }");
      end list;
   begin
      TIO.Put_Line ("Repositories:");
      Config.repositories.Iterate (list'Access);
   end show_repository_info;

end Cmd.Unset;
