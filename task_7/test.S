
#define RVTEST_DATA_BEGIN                                               \
        .pushsection .tohost,"aw",@progbits ;                           \
        .align 6; .global tohost; tohost: .dword 0; .size tohost, 8;    \
        .align 6; .global fromhost; fromhost: .dword 0; .size fromhost, 8;\
        .popsection;                                                    \
        .align 4; .global begin_signature; begin_signature:					
#define RVTEST_CODE_BEGIN                                               
        .section .text.init;                                            
        .align  6;                                                      
        .global _start;

#constant for PMP_REG0_TOR,
.equiv PMP_REG0_TOR, 0x80001000 #4Kb region starting from 0x8000_0000 to 0x8000_1000 
#constant for PMP_REG1_NAPOT,
.equiv PMP_REG1_NAPOT, 0x80001000 #4Kb region starting from 0x8000_1000 to 0x8000_2000


RVTEST_CODE_BEGIN
_start:     

	jal ra, machine_mode

    # trap handler for mode switching traps
    la t0, trap_handler					# store the address of trap_handler in t0
    csrw mtvec, t0							# set the mtvec to trap_handler base address

	# set RLB to 1, to make changes in configuration register
	li t0, 0x4
	csrw mseccfg, t0

    # Locked TOR Region Setup 
    li t0, PMP_REG0_TOR					# TOR upto 0x80001000
    srli t0, t0, 2
    csrw pmpaddr0, t0

	# Locked NAPOT Region Setup 			# region for .text segment of the program with X permissions
    li t0, PMP_REG1_NAPOT					# NAPOT upto 0x80002000 
    srli t0, t0, 2
	ori t0, t0, 0x1ff						# addr[33:2] | 9'b01_1111_1111  FORMUAL=> Region size = 2^(LSZB+3) LSZB=least significant zero bit
    csrw pmpaddr1, t0						# 2^9+3 = 2^12 = 4kb region
	
	
	li t0, 0x07079C89 						
    csrw pmpcfg0, t0


    csrr t0, mstatus

    # Set MML (Machine Mode Lockdown) bit in mseccfg to apply permissions only on machine mode
	li t0, 0x00000001
    csrw mseccfg, t0

    # change permission of TOR region from Read Only to Execute Only
	li t0, 0x07079C8C 						
    csrw pmpcfg0, t0



	
    
	

	exit_test:
	li t0, 1               # Exit code
    la t1, tohost          # Address of tohost
    sw t0, 0(t1)           # Signal exit
    ecall

    j write_tohost
        
trap_handler:                                        
    csrr t4, mcause 			#check the casue of the trap                
    
	li t1, 8					# Handle user ecall trap	
    beq t4, t1, user_ecall_handler                                		
    li t1, 9					# Handle supervisor ecall trap				
    beq t4, t1, supervisor_ecall_handler    
	li t1, 12					# Handle instruction page fault				
    beq t4, t1, instruction_page_fault_handler  

	li t1, 5
	beq t4, t1, handle_load_page_fault

	li t1, 7
	beq t4, t1, handle_store_page_fault

    j write_tohost

handle_load_page_fault:

    csrr t0, mepc
	addi t0, t0, 4
	csrw mepc, t0
	mret

handle_store_page_fault:
	csrr t0, mepc
	addi t0, t0, 4
	csrw mepc, t0
	mret

instruction_page_fault_handler:
	# switch to machine mode	and exit the test																
	csrr t0, mstatus			# read the value of mstatus register							
	li t1, 0xffffe7ff			# load this immediate in t1 0b11111111111111111110111111111111	
	and t0, t0, t1				# clear the 11th and 12th bit of mstatus register to 00			
	li t1, 0x1800				# load this immediate in t1 0b1100000000000 					
	or t0, t0, t1				# set the 11th and 12th bit of mstatus register to 11			
	csrw mstatus, t0			# write t0 to mstatus register		
	la t1, exit_test			
	csrw mepc, t1				# load the addres of exit_test in sepc				
	mret

supervisor_ecall_handler:
	# switch to machine mode																	
	csrr t0, mstatus			# read the value of mstatus register							
	li t1, 0xffffe7ff			# load this immediate in t1 0b11111111111111111110111111111111	
	and t0, t0, t1				# clear the 11th and 12th bit of mstatus register to 00			
	li t1, 0x1800				# load this immediate in t1 0b1100000000000 					
	or t0, t0, t1				# set the 11th and 12th bit of mstatus register to 11			
	csrw mstatus, t0			# write t0 to mstatus register		
	csrr t2, mepc
	addi t2, t2, 4				# add 4 in mepc so that ecall does not execute in machine mode then mret
	csrw mepc, t2							
	mret																			

user_ecall_handler:																			
	# switch to supervisor mode																
	csrr t0, mstatus			# read the value of mstatus register								
	li t1, 0xffffe7ff			# load this immediate in t1 0b11111111111111111110111111111111
	and t0, t0, t1				# clear the 11th and 12th bit of mstatus register to 00				
	li t1, 0x800				# load this immediate in t1 0b0100000000000 						
	or t0, t0, t1				# set the 11th and 12th bit of mstatus register to 01	
	csrw mstatus, t0			# write t0 to mstatus register										
	mret														



# Machine Mode:
machine_mode:
	# switch to machine mode
	csrr t0, mstatus
	li t1, 3 << 11
	or t0, t0, t1
	csrw mstatus, t0
	jr ra


    

.align 2    
write_tohost:
    li gp, 1
    sw gp, tohost, t5
    j write_tohost



RVTEST_DATA_BEGIN
.data										# data segment starts at 0x80003000 as per linker file
.align 4
 	outer_page_table:					# 4kb outer page table located at 0x80003000
		.zero 4096
 	inner_page_table:					# 4kb inner page table located at 0x80004000
		.zero 4096
	random_data:							# 4kb inner page table located at 0x80005000		
		.word 0x123
