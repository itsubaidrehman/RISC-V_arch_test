.section .text
.global _start

_start:
    # Initialize stack pointer
    la sp, stack_top

    # Set up trap handler
    la t0, trap_handler
    csrw mtvec, t0

    # Configure PMP regions
    jal configure_pmp

    # Print initial message
    la a0, init_msg
    jal print_string

    # Switch to Supervisor mode
    jal switch_to_s_mode

    # This is where we continue in S-mode
continue_in_s_mode:
    # Test PMP access in S-mode
    la a0, s_mode_msg
    jal print_string
    jal test_pmp_access

    # Switch back to M-mode and apply PMP restrictions
    jal switch_to_m_mode
    
    # Enable PMP for M-mode by setting MPRV
    li t0, (1 << 17)       # Set MPRV bit in mstatus
    csrs mstatus, t0

    # Test PMP access in M-mode
    la a0, m_mode_msg
    jal print_string
    jal test_pmp_access

    # Exit program
    li a0, 0
    jal exit_program

# PMP Configuration
configure_pmp:
    # Save return address
    addi sp, sp, -4
    sw ra, 0(sp)

    # Configure TOR region (4KB, execute-only)
    la t0, code_section    # Start of code section
    srli t0, t0, 2        # Convert to PMP format
    csrw pmpaddr0, t0     # Set start address
    
    la t0, code_section_end
    srli t0, t0, 2
    csrw pmpaddr1, t0     # Set end address

    # Configure NAPOT region (4KB, read-only)
    la t0, data_section
    srli t0, t0, 2
    ori t0, t0, 0x3FF     # NAPOT encoding for 4KB
    csrw pmpaddr2, t0

    # Configure permissions
    # pmpcfg0: TOR region (execute-only)
    # pmpcfg1: NAPOT region (read-only)
    li t0, (0x2 << 0)      # Execute for TOR
    li t1, (0x5 << 8)      # Read + NAPOT for second region
    or t0, t0, t1
    csrw pmpcfg0, t0

    # Restore return address
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# Switch to Supervisor mode
switch_to_s_mode:
    # Save return address
    addi sp, sp, -4
    sw ra, 0(sp)

    # Set up MEPC for return address
    la t0, continue_in_s_mode
    csrw mepc, t0

    # Set MPP to supervisor mode (01)
    li t0, 3 << 11        # MPP mask
    csrc mstatus, t0      # Clear MPP bits
    li t0, 1 << 11        # Set MPP to supervisor
    csrs mstatus, t0

    # Restore return address
    lw ra, 0(sp)
    addi sp, sp, 4

    mret                  # Return to supervisor mode

# Switch back to Machine mode
switch_to_m_mode:
    # Set MPP to machine mode (11)
    li t0, 3 << 11
    csrs mstatus, t0
    ret

# Test PMP access
test_pmp_access:
    # Save registers
    addi sp, sp, -16
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)

    # Test 1: Read from NAPOT region (should succeed)
    la t0, data_section
    la a0, read_test_msg
    jal print_string
    lw t1, 0(t0)

    # Test 2: Write to NAPOT region (should fail)
    la a0, write_test_msg
    jal print_string
    li t2, 0xdeadbeef
    sw t2, 0(t0)

    # Test 3: Execute from TOR region (should succeed in TOR region)
    la a0, exec_test_msg
    jal print_string
    la t0, code_section
    jalr t0

    # Restore registers
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    addi sp, sp, 16
    ret

# Enhanced Trap Handler
trap_handler:
    # Save registers
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw a0, 16(sp)
    sw a1, 20(sp)
    sw a2, 24(sp)
    sw a3, 28(sp)

    # Get trap cause
    csrr t0, mcause
    csrr t1, mepc
    csrr t2, mtval

    # Check trap cause
    li a1, 1
    beq t0, a1, handle_instruction_fault
    li a1, 5
    beq t0, a1, handle_load_fault
    li a1, 7
    beq t0, a1, handle_store_fault
    j unknown_trap

handle_instruction_fault:
    la a0, instr_fault_msg
    jal print_string
    j trap_exit

handle_load_fault:
    la a0, load_fault_msg
    jal print_string
    j trap_exit

handle_store_fault:
    la a0, store_fault_msg
    jal print_string
    j trap_exit

unknown_trap:
    la a0, unknown_trap_msg
    jal print_string

trap_exit:
    # Increment MEPC to skip faulting instruction
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    # Restore registers
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw a0, 16(sp)
    lw a1, 20(sp)
    lw a2, 24(sp)
    lw a3, 28(sp)
    addi sp, sp, 32
    
    mret

# Print string utility (implementation depends on your environment)
print_string:
    ret

# Exit program utility
exit_program:
    li t0, 1
    la t1, tohost
    sw t0, 0(t1)
    j .

.section .data
.align 12
code_section:
    # Some executable code here
    ret
code_section_end:

.align 12
data_section:
    .word 0x12345678
    .word 0x87654321

# Messages
init_msg:          .string "Initializing PMP regions...\n"
s_mode_msg:        .string "Testing in Supervisor mode:\n"
m_mode_msg:        .string "Testing in Machine mode with PMP:\n"
read_test_msg:     .string "Testing read access...\n"
write_test_msg:    .string "Testing write access...\n"
exec_test_msg:     .string "Testing execute access...\n"
instr_fault_msg:   .string "Instruction access fault!\n"
load_fault_msg:    .string "Load access fault!\n"
store_fault_msg:   .string "Store access fault!\n"
unknown_trap_msg:  .string "Unknown trap!\n"

.section .bss
.align 12
    .space 4096
stack_top:

.section ".tohost","aw",@progbits
.align 4
.global tohost
tohost: .dword 0
.global fromhost
fromhost: .dword 0
