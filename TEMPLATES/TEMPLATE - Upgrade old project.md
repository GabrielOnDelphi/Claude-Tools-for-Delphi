
Here is an old Delphi project (not older than Delphi XE probably)
Read the file.
Bring the project up to date to Delphi 13.1
Review the code.
Make sure it compiles.
Do all this by yourself - I might not be at the computer. 
If you discover interesting stuff (new ideas/features, improvements, or a massive architecture overhaul), create a ToDo.md file.
At the end, create a claude.md file in the folder. Put important things in it (things that otherwise might be difficult for you to rediscover).

## LightSaber 
The project uses LightSaber which was updated meanwhile.
Note that the program might use some old stream routines. Now they are in c:\Projects\LightSaber\_Frozen Streams
Make the program write to disk using the new routines. BUT when reading old files use the old routines to stay compatible with old versions.