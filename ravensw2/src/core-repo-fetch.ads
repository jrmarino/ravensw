--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../License.txt

private with Ada.Containers.Vectors;

with Core.Unix;

package Core.Repo.Fetch is

   function fetch_meta
     (my_repo   : in out A_repo;
      timestamp : Unix.T_epochtime) return Action_Result;

   function fetch_remote_extract_to_file_descriptor
     (my_repo   : in out A_repo;
      filename  : String;
      timestamp : in out Unix.T_epochtime;
      file_size : in out Unix.T_filesize;
      retcode   : out Action_Result) return Unix.File_Descriptor;

private

   package CON renames Ada.Containers;

   function fetch_remote_tmp
     (my_repo   : A_repo;
      filename  : String;
      timestamp : in out Unix.T_epochtime;
      retcode   : out Action_Result) return Unix.File_Descriptor;

   function meta_extract_signature_pubkey
     (arc_fd    : Unix.File_Descriptor;
      retcode   : out Action_Result) return String;

   package Set_File_Contents is new CON.Vectors
     (Element_Type => Text,
      Index_Type   => Natural,
      "="          => SU."=");

   function meta_extract_signature_fingerprints
     (arc_fd : Unix.File_Descriptor;
      fingerprints : out Set_File_Contents.Vector) return Action_Result;

   function file_extension_matches (filename, extension : String) return Boolean;

   function meta_extract_to_file_descriptor
     (arc_fd    : Unix.File_Descriptor;
      target_fd : Unix.File_Descriptor;
      filename  : String) return Action_Result;

   type Signature_Certificate is
      record
         name    : Text;
         sc_sign : Text;
         sc_cert : Text;
         trusted : Boolean;
      end record;

   package Set_Signature_Certificates is new CON.Vectors
     (Element_Type => Signature_Certificate,
      Index_Type   => Natural);

   function archive_extract_archive
     (my_repo  : in out A_repo;
      fd       : Unix.File_Descriptor;
      filename : String;
      dest_fd  : Unix.File_Descriptor;
      cert_set : out Set_Signature_Certificates.Vector) return Action_Result;

   function parse_sigkey
     (encoded_sigkey : String;
      signature      : out Signature_Certificate) return Action_Result;

   function check_fingerprints
     (my_repo  : in out A_repo;
      cert_set : in out Set_Signature_Certificates.Vector) return Boolean;

   function archive_extract_check_archive
     (my_repo   : in out A_repo;
      fd        : Unix.File_Descriptor;
      filename  : String;
      dest_fd   : Unix.File_Descriptor) return Action_Result;

   function fingerprint_certs_verified
     (metafd   : Unix.File_Descriptor;
      cert_set : Set_Signature_Certificates.Vector) return Action_Result;

   function get_tmpdir return String;
   function temporary_directory_available return Boolean;
   function temporary_file_name (basename : String) return String;
   function open_temporary_file (filename : String) return Unix.File_Descriptor;

end Core.Repo.Fetch;
