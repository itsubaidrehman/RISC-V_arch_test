.section .text
.global _start

#constant for PMP_REG0_TOR,
.equiv PMP_REG0_TOR, 0x80001000 #4Kb region starting from 0x8000_0000 to 0x8000_1000 
#constant for PMP_REG1_NAPOT,
.equiv PMP_REG1_NAPOT, 0x80001000 #4Kb region starting from 0x8000_1000 to 0x8000_2000


_start:
    

    # Set up trap handler
    la t0, trap_handler
    csrw mtvec, t0
    
    
    csrr t2, mstatus
    li t0, 3 << 11
    or t2, t2, t0
    csrw mstatus, t2
    #csrr t2, mstatus
    # Configure PMP regions
    jal configure_pmp

    csrr t2, mstatus
    li t3, ~(3 << 11)
    and t2, t3, t2
    li t0, 1 << 11
    or t2, t2, t0
    csrw mstatus, t2
    la t0, supervisor_mode
    csrw mepc, t0
    mret
    
supervisor_mode:

    # Test read, write, and execute in PMP regions (S mode)
    jal test_pmp_access
    
    ecall

    # Switch back to Machine mode
    csrr t2, mstatus
    li t3, (0x3 << 11)    # Clear MPP bits to return to Machine mode
    or t2, t2, t3
    csrw mstatus, t2

    # Test read, write, and execute in PMP regions (M mode)
    jal test_pmp_access

    # Clean exit
    li t0, 1               # Exit code
    la t1, tohost          # Address of tohost
    sw t0, 0(t1)           # Signal exit
    ecall

# PMP configuration
configure_pmp:
    		# TOR Region Setup 
    li t0, PMP_REG0_TOR					# TOR upto 0x80001000
    srli t0, t0, 2
    csrw pmpaddr0, t0
	li t0, 0x0000008c 						# grant execute permissions to TOR region
    csrw pmpcfg0, t0


	# NAPOT Region Setup 
    li t0, PMP_REG1_NAPOT					# NAPOT upto 0x80002000
    srli t0, t0, 2
	ori t0, t0, 0x1ff						# addr[33:2] | 9'b01_1111_1111
    csrw pmpaddr1, t0
	li t0, 0x0000998c 						# grant read permissions to NAPOT region 0x19 and execute permissions to TOR region 0x0C
    csrw pmpcfg0, t0

    ret



# Test PMP access
test_pmp_access:
    mv s0, ra
    # read from TOR region
	li t0, 0x80000000						
	lw t1, 0(t0)

	# write to TOR region
	li t0, 0x80000000						
	li t1, 4
	sw t1, 0(t0)

	# read from NAPOT region
	li t0, 0x80001004						
	lw t1, 0(t0)

	# write to NAPOT region
	li t0, 0x80001004						
	li t1, 4
	sw t1, 0(t0)

	# execute in NAPOT region
	li t0, 0x80001004
	jalr ra, t0, 0
    
    mv ra, s0
    ret

# Trap handler
trap_handler:

    csrr t0, mtval          # Get faulting address
    csrr t0, mcause         # Get trap cause
    
    li t1, 9             # Supervisor ECALL
    beq t0, t1, handle_supervisor_ecall
    
    li t1, 1                # Instruction Access Fault
    beq t0, t1, handle_instruction_fault
    li t1, 5                # Load Access Fault
    beq t0, t1, handle_load_fault
    li t1, 7                # Store/AMO Access Fault
    beq t0, t1, handle_store_fault

    j return_from_trap

handle_load_fault:
	csrr    t0, mepc
	addi    t0, t0, 0x4
	csrw    mepc, t0
	mret						# return back to main
	
handle_store_fault:
	csrr    t0, mepc
	addi    t0, t0, 0x4
	csrw    mepc, t0
	mret						# return back to main

handle_instruction_fault:
	csrw    mepc, ra
	mret						# return back to main

    
handle_supervisor_ecall:

    csrr t0, mstatus
    li t1, 3 << 11
    or t1, t1, t0
    csrw mstatus, t1
    csrr t1, sepc
    # Skip ECALL instruction
    csrr t1, mepc
    addi t1, t1, 4
    csrw mepc, t1
    
    mret

return_from_trap:
    
    csrr t0, mepc           # Increment return address
    addi t0, t0, 4
    csrw mepc, t0
    mret                    # Return from trap
    
# Exit sequence
exit_program:
    li t0, 1               # Exit code 1 (success)
    la t1, tohost          # Address of tohost
    sw t0, 0(t1)           # Signal exit
    j .                    # Wait for simulation to end

# Regions for testing
.section .data
    .align 4
napot_region:
    .word 0x12345678
tor_region:
    .word 0x87654321

# Stack setup
.section .bss
    .align 4
    .space 4096
stack_top:






write_tohost:
li x1, 1
sw x1, tohost, t5
j write_tohost
.data 

n: .word 5




.align 12
.section ".tohost","aw",@progbits;                            
.align 4; .global tohost; tohost: .dword 0;                     
.align 4; .global fromhost; fromhost: .dword 0;


