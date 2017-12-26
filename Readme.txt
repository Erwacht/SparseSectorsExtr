Sparse Sectors Extractor
SparseSectorsExtr.sh version 0.86
(C) 2015 Traie Ward

Often a new, blank hard drive will come with a little bit of non-null data scattered over it. I wrote this Bash script to automatically find all non-null sectors on a hard drive and extract them into files. Continuous data is extracted to individual files, with one further null sector appended at the end. That's simply how I wanted it.

This script got started when I learned, to my surprise, that Linux Bash scripting, unlike DOS batch scripting, has built-in ordinary variable handling (and ordinary while and for loops). I realized immediately that this meant that, using the standard "dd" utility, I could make this disk utility entirely in Bash. So I learned Bash in two days. And two sixteen-hour days later, I had this script.

The one drawback of this script is that each "sudo dd" call for 512 bytes takes so long that to traverse a whole two terabyte hard drive might take an entire year. I never measured how slow it really is. If I really needed it to work, I would rewrite the algorithm to read and process one megabyte at a time, to save "sudo" calls and disk reads. That might actually work. (The real solution is to use "dd" and "hexdump" and a little extra regex processing. Such a job only takes a few hours that way.)

The algorithm as wirtten is correct and stand as the proof that I did learn a new language effectively in two days.


