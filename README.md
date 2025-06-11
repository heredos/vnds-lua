# VNDS-LUA
WIP vnds interpreter written in lua.
meant to be extensible, and frontend-agnostic, meaning, you can do whatever you wan with it, even something that's not VNDS at all, in theory.
Please note that this is currently in developpment as my summer project, and that dome features are meant to be missing (I.E. everything that requires an output device.)

## what is there:
* setvar/gsetvar (with globals saving/loading)
* if/fi
* jump
* label/goto

## what isn't there yet
* random
* saving/loading management

## hat won't be in this repo
* bgload
* setimg
* sound
* music
* text
* cleartext
* delay
those are functions that you will have to implement yourself in the frontend.
I am working on a sample frontend in command line, as well as a full frontend with love2D, stay tuned, i will link them in this readme.

the end goal is to be able to package and run VNDS games for xperia play, then write a frontend for KOreader, and then, maybe reuse the love2D base to make my own visual novel
