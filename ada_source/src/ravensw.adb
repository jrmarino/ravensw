--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: License.txt

with Ada.Command_Line;
with Cmd.Line;
with Cmd.Usage;
with Cmd.Bahnhof;
with Cmd.Event;
with Core.Finalize;

procedure Ravensw
is

   package ACL renames Ada.Command_Line;
   package CB  renames Cmd.Bahnhof;
   package CL  renames Cmd.Line;
   package CU  renames Cmd.Usage;
   package CEV renames Cmd.Event;
   package FIN renames Core.Finalize;

   comline_inputs : Cmd.Cldata;

begin
   comline_inputs := CL.parse_command_line;
   if not CU.command_line_valid (comline_inputs) then
      ACL.Set_Exit_Status (Code => ACL.Failure);
      return;
   end if;

   CEV.handle_event_callbacks (comline_inputs);

   if CB.execute_command (comline_inputs) then
      ACL.Set_Exit_Status (Code => ACL.Success);
   else
      ACL.Set_Exit_Status (Code => ACL.Failure);
   end if;

   FIN.cleanup;

end Ravensw;
