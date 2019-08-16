--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../License.txt

with Ada.Directories;
with Core.Event;
with Core.Unix;

package body Core.Config is

   package DIR renames Ada.Directories;
   package EV  renames Core.Event;

   --------------------------------------------------------------------
   --  pkg_initialized
   --------------------------------------------------------------------
   function pkg_initialized return Boolean is
   begin
      return parsed;
   end pkg_initialized;


   --------------------------------------------------------------------
   --  pkg_init
   --------------------------------------------------------------------
   function pkg_init
     (path     : String;
      reposdir : String) return Pkg_Error_Type is
   begin
      return pkg_ini (path, reposdir, init_none);
   end pkg_init;


   --------------------------------------------------------------------
   --  pkg_config_get
   --------------------------------------------------------------------
   function pkg_config_get (key : String) return access constant libucl.ucl_object_t is
   begin
      return Ucl.ucl_object_find_key (config_object, key);
   end pkg_config_get;


   --------------------------------------------------------------------
   --  pkg_ini
   --------------------------------------------------------------------
   function pkg_ini
     (path     : String;
      reposdir : String;
      flags    : Pkg_init_flags) return Pkg_Error_Type
   is
      rootdir_used : constant Boolean := not IsBlank (context.pkg_rootdir);
      obj          : access constant libucl.ucl_object_t;
   begin
      if not Unix.file_connected (context.rootfd) then
         declare
            flags : Unix.T_Open_Flags;
         begin
            flags.DIRECTORY := True;
            flags.RDONLY    := True;
            flags.CLOEXEC   := True;
            context.rootfd := Unix.open_file ("/", flags);
            if not Unix.file_connected (context.rootfd) then
               EV.pkg_emit_error (SUS ("Impossible to open /"));
               return EPKG_FATAL;
            end if;
         end;
      end if;

      --  TODO: define myabi

      if parsed then
         EV.pkg_emit_error (SUS ("pkg_init() must only be called once"));
         return EPKG_FATAL;
      end if;

      config_object := Ucl.ucl_object_typed_new_object;

      for index in config_entries'Range loop
         case config_entries (index).config_type is
            when pkg_string =>
               declare
                  tmp : Text;
                  tmp_set : Boolean := False;
               begin
                  if rootdir_used and then
                    leads (config_entries (index).default, "/")
                  then
                     SU.Append (tmp, context.pkg_rootdir);
                     SU.Append (tmp, config_entries (index).default);
                     tmp_set := True;
                  end if;
                  if tmp_set then
                     obj := Ucl.ucl_object_fromstring_and_trim (USS (tmp));
                  else
                     obj := Ucl.ucl_object_fromstring_and_trim
                       (USS (config_entries (index).default));
                  end if;
               end;
            when pkg_bool => null;
            when pkg_array => null;
            when pkg_int => null;
            when pkg_object => null;
         end case;
      end loop;

      --  ...
      return EPKG_OK;
   end pkg_ini;


   --------------------------------------------------------------------
   --  connect_evpipe
   --------------------------------------------------------------------
   procedure connect_evpipe (event_pipe : String)
   is
      file_exists : Boolean;
      mechanism   : Unix.Unix_Pipe;
      sock_error  : Text := SUS ("open event pipe (socket)");
      sock_flags  : Unix.T_Open_Flags;
   begin
      begin
         file_exists := DIR.Exists (Name => event_pipe);
      exception
         when others =>
            file_exists := False;
      end;

      if not file_exists then
         EV.pkg_emit_error (SUS ("No such event pipe: " & event_pipe));
         return;
      end if;

      case DIR.Kind (Name => event_pipe) is
         when DIR.Ordinary_File =>
            EV.pkg_emit_error (SUS (event_pipe & " is an ordinary file"));
            return;
         when DIR.Directory =>
            EV.pkg_emit_error (SUS (event_pipe & " is a directory"));
            return;
         when DIR.Special_File =>
            null;
      end case;

      mechanism := Unix.IPC_mechanism (event_pipe);
      case mechanism is

         when Unix.something_else =>
            EV.pkg_emit_error (SUS (event_pipe & " is not a fifo or socket"));

         when Unix.named_pipe =>
            sock_flags.WRONLY := True;
            sock_flags.NON_BLOCK := True;
            context.eventpipe := Unix.open_file (event_pipe, sock_flags);
            if not Unix.file_connected (context.eventpipe) then
               EV.pkg_emit_errno (SUS ("open event pipe (FIFO)"), SUS (event_pipe), Unix.errno);
            end if;

         when Unix.unix_socket =>
            declare
               fd : Unix.File_Descriptor;
            begin
               case Unix.connect_unix_socket (event_pipe, fd) is
                  when Unix.connected =>
                     context.eventpipe := fd;

                  when Unix.failed_creation | Unix.failed_connection =>
                     EV.pkg_emit_errno (sock_error, SUS (event_pipe), Unix.errno);

                  when Unix.failed_population =>
                     EV.pkg_emit_error (SUS ("Socket path too long: " & event_pipe));
               end case;
            end;
      end case;

   end connect_evpipe;

end Core.Config;
