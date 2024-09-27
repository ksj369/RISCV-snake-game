#
# CMPUT 229 Public Materials License
# Version 1.0
#
# Copyright 2020 University of Alberta
# Copyright 2022 Yufei Chen
# TODO: claim your copyright
# This software is distributed to students in the course
# CMPUT 229 - Computer Organization and Architecture I at the University of
# Alberta, Canada.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the disclaimer below in the documentation
#    and/or other materials provided with the distribution.
#
# 2. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#-------------------------------
# Lab_Snake_Game Lab
#
# Author: Khevish Singh Jankee
# Date:  14/11/2022
# TA: james thompson, Siva Chowdeswar Nandipati
#
#-------------------------------

.include "common.s"

.data
.align 2

DISPLAY_CONTROL:    .word 0xFFFF0008
DISPLAY_DATA:       .word 0xFFFF000C
INTERRUPT_ERROR:	.asciz "Error: Unhandled interrupt with exception code: "
INSTRUCTION_ERROR:	.asciz "\n   Originating from the instruction at address: "
TIME:  .word 0xFFFF0018
TIMECMP:  .word 0xFFFF0020
KEYBOARD_CONTROL: .word 0xFFFF0000
KEY_PRESSED: .word 0xFFFF0004
Brick:      .asciz "#"
change1: .word 1
end_game: .word 1
prep:  .asciz"please select 1,2 or 3 to start the game"
body:  .asciz "*"
head:  .asciz"@"
apple: .asciz"a"
move_snake: .word 1
head_pos: .word 6,6  #position of head and body
body1_pos: .word 6,5
body2_pos: .word 6,4
body3_pos: .word 6,3
apple_pos: .word 1,8
displacement: .word 0,1
bonus: .word 0
timer_int:.word 0
points_int: .word 0
zero_ref: .asciz "0"
t1_str: .asciz"0"
t2_str: .asciz"0"
t3_str: .asciz"0"
p1_str: .asciz"0"
p2_str: .asciz"0"
p3_str: .asciz"0"
timer_str: .asciz " seconds"
points_str: .asciz " points"
clear: .asciz"                                         "
blank: .asciz" "

.text


#---------------------------------------
# funtion that starts and run the game
# register usage:
# t0: load imidiate values/address
# t1: load imidiate values/address
# t2: load imidiate values/address
# t3: load imidiate values/address
# a0: string to print
# a1:  row to print
# a2:  col to print
#---------------------------------------
snakeGame:
	
	addi   sp, sp, -4  # update stack
	sw     ra, 0(sp)
	
	la t0,handler
	csrw t0,5  # put handler address in utvec
	li t0,256 
	csrw t0,4 # allow keyboard interrupt 
	li t0,1
	csrw t0,0  #allow user interupt
	
	
	lw t0,KEYBOARD_CONTROL  #enable keyboard control
	li t1,2
	sw t1,0(t0)
	
	
	
	la a0,prep  #print level message
	li a1,0
	li a2,0
	jal printStr
	
	
	

	la t0,change1  # memory address for changed

	
loop1: lw t1,0(t0)   # loop untill correct level is selected 1,2,3
	beq t1,zero,end1
	
	j loop1
	
end1:	li a1,0   #clear select level message then display game walls
	li a2,0
	la a0,clear
	jal printStr
	jal printAllWalls
	
	
	
	jal drawSnake  # display snake
	
	la a0,points_str  # display string "points"
	li a1,0
	li a2,26
	jal printStr
	
	la a0,timer_str  # display string  "seconds"
	li a1,1
	li a2,26
	jal printStr
	
	li t0,272  
	csrw t0,4 # allow keyboard &time interrupt
	
	lw t0,TIME  #start timer
	lw t0,0(t0)
	lw t1,TIMECMP
	addi t2,t0,1000  #timecmp=timecmp+time
	sw t2,0(t1)
	
	jal random  #generate random row for apple and store
	addi a0,a0,1  # random num +1 since rnage 0-8
	la t0,apple_pos
	sw a0,0(t0)
	jal random  # generate random col for apple and store
	addi a0,a0,1  # random num+1
	la t0,apple_pos
	sw a0,4(t0)
	jal drawApple  # display apple, time , point
	jal drawTime
	jal drawPoint
loop2:	
	
	
	
	la t0,move_snake  # check if snake position changed
	lw t1,0(t0)
	bne zero,t1,skip
	jal printAllWalls #print wall again (reason bug : after few seconds wall just dissapear)
	jal drawTime
	
	jal clearSnake  # clear previous snake before drawing new one
	jal drawSnake  #display snake
	jal checkHitting  #check if snake hit walls
	jal checkEating  # check if snake eats apple
	li t1,1
	sw t1,0(t0)
	
	
skip:	la t2,timer_int  # check end of game if timer =0 or timer was set to 0 on hitting wall
	lw t3,0(t2)
	beq zero,t3,end2
	

	
	j loop2  # continue game play
	

	
	
end2:
	#end program:
		
	lw     ra, 0(sp)  # unstack and return
	addi   sp, sp, 4


	ret

#---------------------------------------
# check if apple was eaten by snake
# register usage:
# t0: load/store imidiate values/address
# t1: load/store imidiate values/address
# t2: load/store imidiate values/address
# t3: load/store imidiate values/address
# t4: load/store imidiate values/address
# t5: load/store imidiate values/address
#---------------------------------------
checkEating:
	addi sp,sp,-4  # adjust stack
	sw ra,0(sp)
	
	
	la t0,head_pos
	lw t1,0(t0)  # x-coord
	lw t2,4(t0)  #y-coord
	
	la t3,apple_pos
	lw t4,0(t3)  # apple -x
	lw t5,0(t3)  # apple -y
		
	bne t1,t4,end  # chekc if head x,y coord same as apple
	bne t2,t5,end
	
	la t0,points_int  # increment points counter
	lw t1,0(t0)
	addi t1,t1,1
	sw t1,0(t0)
	
	jal drawPoint  #draw points
	
	#generate new apple coordinate
	jal random  # row coord
	addi a0,a0,1
	la t0,apple_pos  # store new coord
	sw a0,0(t0)
	jal random  # col coord
	addi a0,a0,1
	la t0,apple_pos  # store new coord
	sw a0,4(t0)
	jal drawApple  # display apple
	
	la t0,bonus # load bonus time
	lw t0,0(t0)
	addi t0,t0,-1  # t0= bonus -1
	la t1,timer_int
	lw t2,0(t1)
	add t2,t2,t1  # add t0 to current timer and store timer
	sw t2,0(t1)
	jal drawTime  # display new timer
	
	
end:	lw ra,0(sp)  # unstack and return back
	addi sp,sp,4
	jalr zero,ra,0
	
	
	
#---------------------------------------
# draw apple
# register usage:
# a0: load address
# t1: load address
# a1: row position
# a2: col position
#---------------------------------------

drawApple:
	addi sp,sp,-4  # adjust stack
	sw ra,0(sp)
	
	la a0,apple # load apple character and position
	la t1,apple_pos
	lw a1,0(t1)
	lw a2,4(t1)
	jal printStr  # draw apple
	
	
	lw ra,0(sp)
	addi sp,sp,4   # unstack
	jalr zero,ra,0



	
#---------------------------------------
# generatge random number between 0-8
# register usage:
# t0: load/store imidiate values/address
# t1: load/store imidiate values/address
# t2: load/store imidiate values/address
# t3: load/store imidiate values/address
#---------------------------------------

random:
	addi sp,sp,-4
	sw ra,0(sp)   # adjust stack
	
	la t0,XiVar
	lw t1,0(t0)  #t1=Xi
	la t2,aVar
	lw t3, 0(t2)  #t3=a
	mul t3,t3,t1  # t3=aXi
	la t0,cVar
	lw t1,0(t0)   #t1=c
	add t3,t3,t1  # t3=aXi+c
	la t0,mVar
	lw t1,0(t0) # t1=m
	rem t3,t3,t1  # t3=t3%t1
	la t0,XiVar
	sw t3,0(t0)  #Xi=t3
	
	mv a0,t3  # return number in a0
	
	lw ra,0(sp)  # unstack
	addi sp,sp,4
	jalr zero,ra,0
	
	
#--------------------------------------------
#  check if snake head hits the walls
# t0: load/store imidiate values/address
# t1: load/store imidiate values/address
# t2: load imidiate values

#--------------------------------------------
checkHitting:
	addi sp,sp,-4   # adjust stack
	sw ra,0(sp)
	
	la t0,head_pos  # load head position
	lw t1,0(t0)
	bge zero,t1,hitting   # check if row <=0
	li t2,10
	bge t1,t2,hitting  # check if row>=10
	lw t1,4(t0)
	bge zero,t1,hitting    # check if  col<=0
	li t2,20
	bge t1,t2,hitting    # check if col>=20
	j no_hit  # otherwisse not hitting wall
	
hitting:	la t0,timer_int  # if hitting wall make timer 0 to end main game loop
	li t1,0
	sw t1,0(t0)
	
	
no_hit:	lw ra,0(sp)  # no hitting return back to game
	addi sp,sp,4
	jalr zero,ra,0



#--------------------------------------------
#  clear snake
# t0: load address
# a0: character to print
# a1: row position
# a2: col position

#--------------------------------------------
clearSnake:
	addi sp,sp,-4  # adjust stack
	sw ra,0(sp)
	
	la t0,head_pos  # load address of head position and  space character
	la a0,blank
	lw a1,0(t0)
	lw a2,4(t0)
	jal printStr  # clear head
	
	la t0,body1_pos  # load address of body position and  space character
	la a0,blank
	lw a1,0(t0)
	lw a2,4(t0)
	jal printStr    # clear body
	
	la t0,body2_pos   # load address of body position and  space character
	la a0,blank
	lw a1,0(t0)
	lw a2,4(t0)
	jal printStr    # clear body
	
	la t0,body3_pos    # load address of body position and  space character
	la a0,blank
	lw a1,0(t0)
	lw a2,4(t0)
	jal printStr	    # clear body
	
	
	lw ra,0(sp)  # unstack
	addi sp,sp,4
	jalr zero,ra,0


#---------------------------------------
# calculate and draw timer
# register usage:
# t0: load/store imidiate values/address
# t1: load/store imidiate values/address
# t2: load/store imidiate values/address
# t3: load/store imidiate values/address
# t4: load/store imidiate values/address
# t5: load/store imidiate values/address
# a0: character to print
# a1: row position
# a2: col position
#---------------------------------------
drawTime:
	addi sp,sp,-4
	sw ra,0(sp)
	
la t0,timer_int  # load timer 
li t1,100
lw t0,0(t0)
div t1,t0,t1  #t1=timer /100

#calculate 1st digit
la t0,zero_ref  # zero reference to add numbers to display
lbu t2,0(t0)  # load character 0
add t2,t2,t1  # add t1 to 0
la t5,t1_str
sb t2,0(t5)  # store t1



la t0,timer_int
li t2,100
lw t0,0(t0)

mul t2,t2,t1 # t2=t1*100
sub t4,t0,t2  # t4=timer-t2
li t2,10
div t2,t4,t2  # t2=t4/10

#calculate 2nd digit in string form
la t0,zero_ref
lbu t1,0(t0)
add t1,t1,t2
la t5,t2_str
sb t1,0(t5)

# calculate 3rd digit in string form
li t0,10
mul t0,t0,t2  # t0=t2*10
sub t4,t4,t0  # t4=t4-t0

la t0,zero_ref  # calculate string form
lbu t2,0(t0)
add t2,t2,t4
la t5,t3_str
sb t2,0(t5)


	
	#display time
	la a0,t1_str  # display 1st digit
	li a1,1
	li a2,23
	jal printStr

	la a0,t2_str  # display 2nd digit
	li a1,1
	li a2,24
	jal printStr	
	
	la a0,t3_str   # display  3rd digit
	li a1,1
	li a2,25
	jal printStr
	
	lw ra,0(sp)  # unstack 
	addi sp,sp,4
	jalr zero,ra,0
	

	
#---------------------------------------
# calculate and draw points
# register usage:
# t0: load/store imidiate values/address
# t1: load/store imidiate values/address
# t2: load/store imidiate values/address
# t3: load/store imidiate values/address
# t4: load/store imidiate values/address
# t5: load/store imidiate values/address
# a0: character to print
# a1: row position
# a2: col position
#---------------------------------------	
drawPoint:
	addi sp,sp,-4  # adjust stack
	sw ra,0(sp)
	
	
la t0,points_int  #load points counter
li t1,100
lw t0,0(t0)
div t1,t0,t1  # divide by 100 to get 1st digit

#calculate 1st digit in string
la t0,zero_ref
lbu t2,0(t0)
add t2,t2,t1  # use zero reference to change ascii value
la t5,p1_str
sb t2,0(t5)



la t0,points_int
li t2,100
lw t0,0(t0)  # eliminate 100's 

mul t2,t2,t1
sub t4,t0,t2  # divide by 10 to get 2nd digit remainder
li t2,10
div t2,t4,t2

#calculate 2nd digit in string
la t0,zero_ref
lbu t1,0(t0)
add t1,t1,t2
la t5,p2_str
sb t1,0(t5)

# calculate 3rd digit in string
li t0,10
mul t0,t0,t2
sub t4,t4,t0

la t0,zero_ref
lbu t2,0(t0)
add t2,t2,t4
la t5,p3_str
sb t2,0(t5)

	
	
	
	la a0,p1_str  # display 1st digit
	li a1,0
	li a2,23
	jal printStr

	la a0,p2_str  # display 2nd digit
	li a1,0
	li a2,24
	jal printStr	
	
	la a0,p3_str  # display 3rd digit
	li a1,0
	li a2,25
	jal printStr
	
	lw ra,0(sp)  # unstack
	addi sp,sp,4
	jalr zero,ra,0

#---------------------------------------
# calculate and draw timer
# register usage:
# t0: load/store imidiate values/address
# a0: character to print
# a1: row position
# a2: col position
#---------------------------------------
drawSnake:
	#stack
	addi sp,sp,-4
	sw ra,0(sp)
	
	la t0,head_pos #load head position and character
	la a0,head
	lw a1,0(t0)
	lw a2,4(t0)
	jal printStr  # display head
	
	la t0,body1_pos # load body position and character
	la a0,body
	lw a1,0(t0)
	lw a2,4(t0)  # display body
	jal printStr
	
	la t0,body2_pos  # load body position and character 
	la a0,body
	lw a1,0(t0)
	lw a2,4(t0)  # display body
	jal printStr
	
	la t0,body3_pos #  load body position and character 
	la a0,body
	lw a1,0(t0)
	lw a2,4(t0)  #  display body
	jal printStr	
	
	#unstack
	lw ra,0(sp)
	addi   sp, sp, 4

	jalr zero,ra,0



#---------------------------------------
# interrupt to handle time and keyboard interrupt
# register usage:
# t0: load/store imidiate values/address
# t1: load/store imidiate values/address
# t2: load/store imidiate values/address
# t3: load/store imidiate values/address
# a1: temporary variable
# a2: temporary variable
#---------------------------------------
handler:
	
	# swap uscratch and a0
csrrw a0, 0x040, a0 # a0 <- Addr[iTrapData], uscratch <- USERa0
# save registers used in the handler EXCEPT a0
sw t0, 0(a0) 
sw t1, 4(a0) 
sw a1, 8(a0)
sw a2,12(a0)
sw t2,16(a0)
sw t3, 20(a0)
# store USERa0
csrr t0, 0x040 # t0 <- USERa0
sw t0, 24(a0) # save USERa0

#la t0,change1 # check if level has already been selected to proceed time interupt
#lw t1,0(t0)
#bne zero,t1,keyboard	

csrr t0,66  # check cause of interrupt  and see if it is time interrupt
li t1,0x80000004
bne t0,t1,keyboard



#check time interrupt

lw t0,TIMECMP  # timecmp
lw t1,TIME  #time
lw t2,0(t0)
lw t3,0(t1)
blt t3,t2, keyboard  # check timecmp<time
# increment timecmp#
addi t2,t3,1000 # t2=time+1000 1second
sw t2,0(t0)
la t0,timer_int
lw t1,0(t0)
addi t1,t1,-1
sw t1,0(t0)

#move snake
la t0,move_snake
li t1,0
sw t1,0(t0)
	#body3 position <-  body2 position
la t0,body3_pos
la t1,body2_pos
lw t2,0(t1)
sw t2,0(t0)
lw t2,4(t1)
sw t2,4(t0)

	#body2 position <-  body1 position
la t0,body2_pos
la t1,body1_pos
lw t2,0(t1)
sw t2,0(t0)
lw t2,4(t1)
sw t2,4(t0)

	#body1 position <-  head_pos position
la t0,body1_pos
la t1,head_pos
lw t2,0(t1)
sw t2,0(t0)
lw t2,4(t1)
sw t2,4(t0)

	#move head by adding dislpacement vector
la t0,displacement
la t1,head_pos
lw t2,0(t0)  # x-displacement
lw t3,0(t1)  # x coordinate of head
add t3,t3,t2  # add coordinate and displacement
sw t3,0(t1)
lw t2,4(t0)   #y-coordinate
lw t3,4(t1)
add t3,t3,t2
sw t3,4(t1)

j done  # timer interrupt done

keyboard:
#check keyboard interupt
	la t0,change1  # if level has already been selected then
	lw t1,0(t0)
	beq zero,t1,move  #  check for movement interrupts w,a,s,d
	
	li t1,49 # ascci value of 1
	li t2,50 # ascii value of 2
	li t3,51 # ascii value of 3
	lw t0,KEY_PRESSED# last key pressed address

		
lvl:   # loop until level is selected from 1,2,3
	lbu a0,0(t0),
	beq a0,t1,lv1
	beq a0,t2,lv2
	beq a0,t3,lv3
	beq zero,zero,lvl
	
lv1:	la t0,timer_int
	li t1,120
	sw t1,0(t0)
	li t1,8
	la t0,bonus
	sw t1,0(t0)
	j init
	
lv2:	la t0,timer_int
	li t1,30
	sw t1,0(t0)
	li t1,5
	la t0,bonus
	sw t1,0(t0)
	j init

lv3:    la t0,timer_int
	li t1,15
	sw t1,0(t0)
	li t1,3
	la t0,bonus
	sw t1,0(t0)
	j init
 
init:	li t1,0
	la t0,change1  # memory address for changed
	sw t1,0(t0)
	lw t0,KEYBOARD_CONTROL  #enable keyboard control after interupt
	li t1,2
	sw t1,0(t0)
	j done
	
move:	li t1,119 # ascci value of w
	li t2,97 # ascii value of a
	li t3,115 # ascii value of s
	li t4,100 # ascii value of d
	lw t0,KEY_PRESSED# last key pressed address

		
 
	lbu a0,0(t0)  # check which key was pressed
	beq a0,t1,up
	beq a0,t2,left
	beq a0,t3,down
	beq a0,t4, right
	j done
	#beq zero,zero,direction

up: 	la t0,displacement # load displacement
	li t1,-1  # row 
	li t2,0   # col
	sw t1,0(t0)  # store new displacement of snake
	sw t2,4(t0)
	j done

left:	la t0,displacement  # load new displacement
	li t1,0  # row 
	li t2,-1   # col
	sw t1,0(t0)
	sw t2,4(t0)  # store new displacement of snake
	j done

down:	la t0,displacement  # load displacement
	li t1,1  # row 
	li t2,0   # col
	sw t1,0(t0)
	sw t2,4(t0)  # store new displacement of snake
	j done
	
right:	la t0,displacement  # load displacement 
	li t1,0  # row 
	li t2,1   # col
	sw t1,0(t0)
	sw t2,4(t0)  # store new displacement of snake
	j done

done:    	
lw t0,KEYBOARD_CONTROL  #enable keyboard control after interupt
	li t1,2
	sw t1,0(t0)

# load USERa0
# assuming that iTrapData has already been created and used as a global varibale

la      a0, iTrapData # a0 <- Addr[iTrapData]
lw      t0, 24(a0)    # t0 <- USERa0
csrw t0, 0x040        # uscratch <- usera0
# load registers used in the handler EXCEPT a0
lw t0, 0(a0) 
lw t1, 4(a0) 
lw a1, 8(a0)
lw a2,12(a0)
lw t2,16(a0)
lw t3, 20(a0)
# swap uscratch and a0
csrrw a0, 0x040, a0  # a0 <- USERa0, uscratch <- Addr[iTrapData]

uret   


handlerTerminate:
	# Print error msg before terminating
	li     a7, 4
	la     a0, INTERRUPT_ERROR
	ecall
	li     a7, 34
	csrrci a0, 66, 0
	ecall
	li     a7, 4
	la     a0, INSTRUCTION_ERROR
	ecall
	li     a7, 34
	csrrci a0, 65, 0
	ecall
handlerQuit:
	li     a7, 10
	ecall	# End of program








#---------------------------------------------------------------------------------------------
# printAllWalls
#
# Subroutine description: This subroutine prints all the walls within which the snake moves
# 
#   Args:
#  		None
#
# Register Usage
#      s0: the current row
#      s1: the end row
#
# Return Values:
#	None
#---------------------------------------------------------------------------------------------
printAllWalls:
	# Stack
	addi   sp, sp, -12
	sw     ra, 0(sp)
	sw     s0, 4(sp)
	sw     s1, 8(sp)
	# print the top wall
	li     a0, 21
	li     a1, 0
	li     a2, 0
	la     a3, Brick
	lbu    a3, 0(a3)
	jal    ra, printMultipleSameChars

	li     s0, 1	# s0 <- startRow
	li     s1, 10	# s1 <- endRow
printAllWallsLoop:
	bge    s0, s1, printAllWallsLoopEnd
	# print the first brick
	la     a0, Brick	# a0 <- address(Brick)
	lbu    a0, 0(a0)	# a0 <- '#'
	mv     a1, s0		# a1 <- row
	li     a2, 0		# a2 <- col
	jal    ra, printChar
	# print the second brick
	la     a0, Brick
	lbu    a0, 0(a0)
	mv     a1, s0
	li     a2, 20
	jal    ra, printChar
	
	addi   s0, s0, 1
	jal    zero, printAllWallsLoop

printAllWallsLoopEnd:
	# print the bottom wall
	li     a0, 21
	li     a1, 10
	li     a2, 0
	la     a3, Brick
	lbu    a3, 0(a3)
	jal    ra, printMultipleSameChars

	# Unstack
	lw     ra, 0(sp)
	lw     s0, 4(sp)
	lw     s1, 8(sp)
	addi   sp, sp, 12
	jalr   zero, ra, 0


#---------------------------------------------------------------------------------------------
# printMultipleSameChars
# 
# Subroutine description: This subroutine prints white spaces in the Keyboard and Display MMIO Simulator terminal at the
# given row and column.
# 
#   Args:
#   a0: length of the chars
# 	a1: row - The row to print on.
# 	a2: col - The column to start printing on.
#   a3: char to print
#
# Register Usage
#      s0: the remaining number of cahrs
#      s1: the current row
#      s2: the current column
#      s3: the char to be printed
#
# Return Values:
#	None
#---------------------------------------------------------------------------------------------
printMultipleSameChars:
	# Stack
	addi   sp, sp, -20
	sw     ra, 0(sp)
	sw     s0, 4(sp)
	sw     s1, 8(sp)
	sw     s2, 12(sp)
	sw     s3, 16(sp)

	mv     s0, a0
	mv     s1, a1
	mv     s2, a2
	mv     s3, a3

# the loop for printing the chars
printMultipleSameCharsLoop:
	beq    s0, zero, printMultipleSameCharsLoopEnd   # branch if there's no remaining white space to print
	# Print character
	mv     a0, s3	# a0 <- char
	mv     a1, s1	# a1 <- row
	mv     a2, s2	# a2 <- col
	jal    ra, printChar
		
	addi   s0, s0, -1	# s0--
	addi   s2, s2, 1	# col++
	jal    zero, printMultipleSameCharsLoop

# All the printing chars work is done
printMultipleSameCharsLoopEnd:	
	# Unstack
	lw     ra, 0(sp)
	lw     s0, 4(sp)
	lw     s1, 8(sp)
	lw     s2, 12(sp)
	lw     s3, 16(sp)
	addi   sp, sp, 20
	jalr   zero, ra, 0


#------------------------------------------------------------------------------
# printStr
#
# Subroutine description: Prints a string in the Keyboard and Display MMIO Simulator terminal at the
# given row and column.
#
# Args:
# 	a0: strAddr - The address of the null-terminated string to be printed.
# 	a1: row - The row to print on.
# 	a2: col - The column to start printing on.
#
# Register Usage
#      s0: The address of the string to be printed.
#      s1: The current row
#      s2: The current column
#      t0: The current character
#      t1: '\n'
#
# Return Values:
#	None
#
# References: This peice of code is adjusted from displayDemo.s(Zachary Selk, Jul 18, 2019)
#------------------------------------------------------------------------------
printStr:
	# Stack
	addi   sp, sp, -16
	sw     ra, 0(sp)
	sw     s0, 4(sp)
	sw     s1, 8(sp)
	sw     s2, 12(sp)

	mv     s0, a0
	mv     s1, a1
	mv     s2, a2

# the loop for printing string
printStrLoop:
	# Check for null-character
	lb     t0, 0(s0)
	# Loop while(str[i] != '\0')
	beq    t0, zero, printStrLoopEnd

	# Print Char
	mv     a0, t0
	mv     a1, s1
	mv     a2, s2
	jal    ra, printChar

	addi   s0, s0, 1	# i++
	addi   s2, s2, 1	# col++
	jal    zero, printStrLoop

printStrLoopEnd:
	# Unstack
	lw     ra, 0(sp)
	lw     s0, 4(sp)
	lw     s1, 8(sp)
	lw     s2, 12(sp)
	addi   sp, sp, 16
	jalr   zero, ra, 0



#------------------------------------------------------------------------------
# printChar
#
# Subroutine description: Prints a single character to the Keyboard and Display MMIO Simulator terminal
# at the given row and column.
#
# Args:
# 	a0: char - The character to print
#	a1: row - The row to print the given character
#	a2: col - The column to print the given character
#
# Register Usage
#      s0: The character to be printed.
#      s1: the current row
#      s2: the current column
#      t0: Bell ascii 7
#      t1: DISPLAY_DATA
#
# Return Values:
#	None
#
# References: This peice of code is adjusted from displayDemo.s(Zachary Selk, Jul 18, 2019)
#------------------------------------------------------------------------------
printChar:
	# Stack
	addi   sp, sp, -16
	sw     ra, 0(sp)
	sw     s0, 4(sp)
	sw     s1, 8(sp)
	sw     s2, 12(sp)
	# save parameters
	mv     s0, a0
	mv     s1, a1
	mv     s2, a2

	jal    ra, waitForDisplayReady

	# Load bell and position into a register
	addi   t0, zero, 7	# Bell ascii
	slli   s1, s1, 8	# Shift row into position
	slli   s2, s2, 20	# Shift col into position
	or     t0, t0, s1
	or     t0, t0, s2	# Combine ascii, row, & col
	
	# Move cursor
	lw     t1, DISPLAY_DATA
	sw     t0, 0(t1)
	jal    waitForDisplayReady	# Wait for display before printing
	
	# Print char
	lw     t0, DISPLAY_DATA
	sw     s0, 0(t0)
	
	# Unstack
	lw     ra, 0(sp)
	lw     s0, 4(sp)
	lw     s1, 8(sp)
	lw     s2, 12(sp)
	addi   sp, sp, 16
	jalr   zero, ra, 0



#------------------------------------------------------------------------------
# waitForDisplayReady
#
# Subroutine description: A method that will check if the Keyboard and Display MMIO Simulator terminal
# can be writen to, busy-waiting until it can.
#
# Args:
# 	None
#
# Register Usage
#      t0: used for DISPLAY_CONTROL
#
# Return Values:
#	None
#
# References: This peice of code is adjusted from displayDemo.s(Zachary Selk, Jul 18, 2019)
#------------------------------------------------------------------------------
waitForDisplayReady:
	# Loop while display ready bit is zero
	lw     t0, DISPLAY_CONTROL
	lw     t0, 0(t0)
	andi   t0, t0, 1
	beq    t0, zero, waitForDisplayReady
	jalr   zero, ra, 0
