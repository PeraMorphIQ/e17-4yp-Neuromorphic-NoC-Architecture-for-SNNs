# =============================================================================
# Multi-Node SNN Communication Test
# =============================================================================
# Description: Test inter-node spike propagation in 2x2 mesh
#              Node (0,0): Source neurons
#              Node (1,0): Intermediate processing
#              Node (0,1): Intermediate processing
#              Node (1,1): Output neurons
#
# Author: Neuromorphic Accelerator Team
# =============================================================================

.section .text
.globl _start

_start:
    li sp, 0x10000
    la t0, spike_isr
    csrw mtvec, t0

    # Get node coordinates (stored in special registers or memory)
    # For simulation, assume defined at compile time
    # NODE_X and NODE_Y would be defined per-node

    jal node_specific_init
    jal multi_node_test

halt:
    j halt


# =============================================================================
# Node-Specific Initialization
# =============================================================================
node_specific_init:
    # Configure neurons based on which node this is
    # Simplified - in real code, would check node ID

    # Configure all local neurons
    li a0, 0
    jal configure_lif_neuron

    li a0, 1
    jal configure_lif_neuron

    li a0, 2
    jal configure_lif_neuron

    li a0, 3
    jal configure_lif_neuron

    ret


# =============================================================================
# Multi-Node Communication Test
# =============================================================================
multi_node_test:
    addi sp, sp, -4
    sw ra, 0(sp)

    # If this is Node (0,0), inject input
    # (Check node ID - simplified for now)

    # Inject to neuron 0
    li a0, 0
    li a1, 0x42C80000       # 100.0
    jal inject_current

    # Wait for spike
    li t0, 1000
wait_spike:
    addi t0, t0, -1
    bnez t0, wait_spike

    # Check if neuron 0 spiked
    li a0, 0
    jal check_spike
    beqz a0, no_spike

    # Propagate to Node (1,0), Neuron 1
    li a0, 0                # Source neuron
    li a1, 0x10             # Dest: Node(1,0)
    li a2, 1                # Dest neuron 1
    li a3, 0x40000000       # Weight 2.0
    jal propagate_spike

    # Also propagate to Node (0,1), Neuron 2
    li a0, 0
    li a1, 0x01             # Dest: Node(0,1)
    li a2, 2
    li a3, 0x40400000       # Weight 3.0
    jal propagate_spike

no_spike:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# =============================================================================
# Configure LIF Neuron
# =============================================================================
configure_lif_neuron:
    li t0, 0x80000000
    slli t1, a0, 5
    add t0, t0, t1

    li t1, 0                # Type = LIF
    sw t1, 0x00(t0)

    li t1, 0xC2480000       # v_th = -50.0
    sw t1, 0x04(t0)

    li t1, 0xBF800000       # a = -1.0
    sw t1, 0x08(t0)

    li t1, 0x3F800000       # b = 1.0
    sw t1, 0x0C(t0)

    ret


# =============================================================================
# Inject Current
# =============================================================================
inject_current:
    li t0, 0x80000000
    slli t1, a0, 5
    add t0, t0, t1
    sw a1, 0x18(t0)
    ret


# =============================================================================
# Check Spike
# =============================================================================
check_spike:
    li t0, 0x80000000
    slli t1, a0, 5
    add t0, t0, t1
    lw t1, 0x1C(t0)
    andi a0, t1, 0x01
    ret


# =============================================================================
# Propagate Spike
# =============================================================================
propagate_spike:
    # Build packet
    slli t0, a1, 16
    andi t1, a2, 0xFFFF
    or t0, t0, t1

    # Send via SWNET (custom instruction)
    # Placeholder for actual instruction
    # SWNET a3, t0, 0

    ret


# =============================================================================
# Interrupt Service Routine
# =============================================================================
spike_isr:
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw a0, 24(sp)
    sw a1, 28(sp)

isr_loop:
    # Read packet from network
    # LWNET t0, zero, 0
    # Check valid flag in t1
    beqz t1, isr_done

    # Extract neuron ID
    andi t2, t0, 0xFFFF

    # Update neuron input
    li t3, 0x80000000
    slli t4, t2, 5
    add t3, t3, t4

    # Add weight to input (simplified)
    lw a0, 0x18(t3)
    li a1, 0x3F800000       # Weight 1.0
    # fadd.s (would add weights properly)
    sw a1, 0x18(t3)

    j isr_loop

isr_done:
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw a0, 24(sp)
    lw a1, 28(sp)
    addi sp, sp, 32
    mret
