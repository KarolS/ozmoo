#magic-tweaks branch

This branch adds several features that were deemed too controversial to include in mainline ozmoo:

* detection of unused z-machine opcodes (`-ru`)

    * requires `txd` from ztools
    
    * redirects unused opcodes to a crash routine, making the interpreter smaller
    
    * unless the game uses code generation or self-modifying code, it should work correctly

* illegal opcode support (`-il`)

    * works only on original CPU's from MOS/CSG
    
    * makes the intererpreter marginally smaller and faster

* ASCII support removal option (`-cm:zz`)

    * removes all non-PETSCII characters mappings
    
    * makes the interpreter marginally smaller and faster
