# rd-level-merger
  A level merger for Rhythm Doctor made with LÖVE (https://love2d.org/) that takes in multiple .rdlevels and combines them all into one.

  Each rdlevel you input has a few settings you can modify to specify what type of events to appear in the final product from said rdlevel.
For example, if you want the rows from the first rdlevel and the VFX from the second simply change the settings for the first to only include the rows and for the second to only include the VFX.

  Of note, the levels are merged into the final product in the order they're given to the program (level 1 will be merged first, then comes level 2, then comes level 3 etc.). This usually doesn't matter, but for when you merge rows it can pose a problem as the program will not merge rows if the room the row is in already has 4 patients so as to avoid issues like some rows not appearing in the final rdlevel due to the limit being reached.
  Also, the final rdlevel will have the metadata (difficulty, author, song title, song artist etc.) of the first rdlevel given.
  
  Any issues like crashes or just bugs I didn't think of can be reported here or straight to me at 9thCore#5404! I might forget about this repo though sometimes so reporting here might not grant an immediate response.
  
  Types of events are also hardcoded into the program, so events whose type aren't added may not be merged into the final result.

  I have no idea how to make releases for Linux and Mac using LÖVE and I don't really have anything to test on to make sure it works so you'll have to compile the program yourself if you use one of those or use a program to run executables on your pc. Sorry!
