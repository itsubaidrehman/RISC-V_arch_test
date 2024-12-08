
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



RVTEST_CODE_BEGIN
_start:     

	jal ra, machine_mode

    # trap handler for mode switching traps
    la t0, trap_handler					# store the address of trap_handler in t0
    csrw mtvec, t0							# set the mtvec to trap_handler base address

	# Setup the PTEs for Instruction memory address (or DMem: load/store addresses).
	# arguments to setup the 0th entry of outer_page_table or level 1 page table
	li a0, 	0x00000000						# Virtual address
	li a1, 	0x80000000						# Physical address
	li a2, 	0x000000CF						# Permissions D (dirty), A (accessed), X and Valid, then changed to RWX & valid to check with and without permissions
	li a3, 	0x00000001						# Level = 1

	jal setup_pte

	# arguments to setup the 0th entry of inner_page_table or level 0 page table
	li a0, 	0x00000158						
	li a1, 	0x80000000						 
	li a2, 	0x000000CF						
	li a3, 	0x00000000						 

	jal setup_pte



	# setup satp register to turn on virtual memory and enable sv32 mode
	la t0, outer_page_table				# get the address of level 1 page table
	srli t0, t0, 12
	li t1, 0x80000000						# set the mode bit to 1
	or t0, t0, t1
	csrw satp, t0


    # switch to supervisor mode
    
	la t0, translation
	li t1, 0x00000FFF							# get the offset the append it at lower 12 bits in VA
	and t1, t0, t1		
	csrw mepc, t1								# store virtual address in mepc whose mapping is stored in page table

    csrr t0, mstatus
    li t1, ~(0x1800)
    and t0, t0, t1
    li t1, 1 << 11
    or t0, t0, t1
    csrw mstatus, t0
	mret	
	
translation:
	la a3, random_data
	lw t1, 0(a3)

	li t3, 0x4
	sw t3, 0(a3)
	

	exit_test:
	li t0, 1               # Exit code
    la t1, tohost          # Address of tohost
    sw t0, 0(t1)           # Signal exit


    j write_tohost
        
trap_handler:                                        
    csrr t4, mcause 			#check the casue of the trap                
    li t1, 2					# Handle illegal instruction trap	
    beq t4, t1, illegal_instruction_handler
	li t1, 8					# Handle user ecall trap	
    beq t4, t1, user_ecall_handler                                		
    li t1, 9					# Handle supervisor ecall trap				
    beq t4, t1, supervisor_ecall_handler    
	li t1, 12					# Handle instruction page fault				
    beq t4, t1, instruction_page_fault_handler  

	li t1, 13
	beq t4, t1, handle_load_page_fault

	li t1, 15
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


illegal_instruction_handler:																			
	# switch to machine mode																
	csrr t0, mstatus			# read the value of mstatus in reg t0
	la t1, exit_test			
	csrw mepc, t1				# load the addres of exit_test in sepc				
	mret				

instruction_page_fault_handler:
	
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
	csrr t0, mstatus											
	li t1, 0xffffe7ff			
	and t0, t0, t1								
	li t1, 0x800										
	or t0, t0, t1					
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

# Function to setup page table entry
setup_pte:

	# check if level = 0 or level = 1
	li t0, 0
	beq a3, t0, level_0_pte					# level 0 = inner page table
	li t0, 1
	beq a3, t0, level_1_pte					# level 1 = outer page table
	jr ra

level_0_pte:								# inner page table
	la t0, inner_page_table

	srli t1, a0, 12							# get out the VPN[0] bits from the virtual address saved in a0
	andi t1, t1, 0x3FF						# add with 0x3ff becasue I need VPN[0] bits, 10 bits
	slli t1, t1, 2							# to allign it with 4 byte pte, next entry is at next 4th byte 
	
	# Extract PPN
	srli a1, a1, 12							# get out the physical page number from physical address
	slli a1, a1, 10							# to store them in pte, we need to get them at 10 bit left
	or a1, a2, a1							# or with permission bits
	add  t0, t0 ,t1							# location of pte where we want to write pte
	sw   a1, 0(t0)							# store physical address at pte location
	jr ra

level_1_pte:								# outer page table
	la t0, outer_page_table
 
	srli t1, a0, 22							# get out the VPN[1] bits from the virtual address saved in a0
	andi t1, t1, 0x3FF
	slli t1, t1, 2							# to allign it with 4 byte pte, next entry is at next 4th byte

	# Extract PPN 
	srli a1, a1, 12							# get out the physical page number from physical address
	slli a1, a1, 10							# to store them in pte, we need to get them at 10 bit left
	or a1, a2, a1							# or with permission bits
	add  t0, t0 ,t1							# location of pte where we want to write pte
	sw   a1, 0(t0)							# store physical address at pte location
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
