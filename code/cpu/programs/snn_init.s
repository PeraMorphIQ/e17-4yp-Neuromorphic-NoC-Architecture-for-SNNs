# =============================================================================
# SNN Initialization and Configuration Program
# =============================================================================
# Description: Assembly program to initialize and configure neurons for
#              Spiking Neural Network simulation on RISC-V RV32IMF core
#
# Memory Map:
#   Neuron Bank Base: 0x80000000
#   Register Offsets:
#     0x00: Neuron Type (per neuron)
#     0x04: Threshold (v_th)
#     0x08: Parameter 'a'
#     0x0C: Parameter 'b'
#     0x10: Parameter 'c'
#     0x14: Parameter 'd'
#     0x18: Input Buffer
#     0x1C: Status (spike/busy)
#
# Author: Neuromorphic Accelerator Team
# =============================================================================

.section .text
.globl _start

_start:
    # Initialize stack pointer
    li sp, 0x10000          # Stack at 64KB

    # Setup interrupt vector
    la t0, spike_isr
    csrw mtvec, t0          # Set ISR address in MTVEC

    # Enable interrupts (simplified - set MIE bit)
    li t0, 0x8
    csrw mstatus, t0

    # Call main initialization
    jal main

    # Halt after completion
halt:
    j halt


# =============================================================================
# Main Initialization Function
# =============================================================================
main:
    addi sp, sp, -4
    sw ra, 0(sp)

    # Configure all 4 neurons in the bank
    li a0, 0                # Neuron ID 0
    jal configure_lif_neuron

    li a0, 1                # Neuron ID 1
    jal configure_lif_neuron

    li a0, 2                # Neuron ID 2
    jal configure_izhikevich_neuron

    li a0, 3                # Neuron ID 3
    jal configure_izhikevich_neuron

    # Start SNN simulation loop
    jal snn_simulation_loop

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# =============================================================================
# Configure LIF Neuron
# =============================================================================
# Input: a0 = neuron_id (0-3)
# Uses: t0-t3
configure_lif_neuron:
    addi sp, sp, -4
    sw ra, 0(sp)

    # Calculate neuron base address
    # Base = 0x80000000 + (neuron_id * 0x20)
    li t0, 0x80000000       # Neuron bank base
    slli t1, a0, 5          # neuron_id * 32
    add t0, t0, t1          # t0 = neuron base address

    # Set neuron type = 0 (LIF)
    li t1, 0
    sw t1, 0x00(t0)

    # Set threshold v_th = -50.0 (0xC2480000 in IEEE 754)
    li t1, 0xC2480000
    sw t1, 0x04(t0)

    # Set parameter 'a' = -1.0 (0xBF800000)
    li t1, 0xBF800000
    sw t1, 0x08(t0)

    # Set parameter 'b' = 1.0 (0x3F800000)
    li t1, 0x3F800000
    sw t1, 0x0C(t0)

    # Parameters c and d not used for LIF, but set to 0
    li t1, 0
    sw t1, 0x10(t0)
    sw t1, 0x14(t0)

    # Initialize input buffer to 0
    sw t1, 0x18(t0)

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# =============================================================================
# Configure Izhikevich Neuron
# =============================================================================
# Input: a0 = neuron_id (0-3)
# Uses: t0-t3
configure_izhikevich_neuron:
    addi sp, sp, -4
    sw ra, 0(sp)

    # Calculate neuron base address
    li t0, 0x80000000
    slli t1, a0, 5
    add t0, t0, t1

    # Set neuron type = 1 (Izhikevich)
    li t1, 1
    sw t1, 0x00(t0)

    # Set threshold v_th = 30.0 (0x41F00000)
    li t1, 0x41F00000
    sw t1, 0x04(t0)

    # Set parameter 'a' = 0.02 (0x3CA3D70A)
    li t1, 0x3CA3D70A
    sw t1, 0x08(t0)

    # Set parameter 'b' = 0.2 (0x3E4CCCCD)
    li t1, 0x3E4CCCCD
    sw t1, 0x0C(t0)

    # Set parameter 'c' = -65.0 (0xC2820000)
    li t1, 0xC2820000
    sw t1, 0x10(t0)

    # Set parameter 'd' = 8.0 (0x41000000)
    li t1, 0x41000000
    sw t1, 0x14(t0)

    # Initialize input buffer to 0
    li t1, 0
    sw t1, 0x18(t0)

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# =============================================================================
# SNN Simulation Loop
# =============================================================================
snn_simulation_loop:
    addi sp, sp, -4
    sw ra, 0(sp)

simulation_timestep:
    # Inject input current to neuron 0
    li a0, 0                # Neuron ID
    li a1, 0x40A00000       # Current = 5.0
    jal inject_current

    # Wait for neuron computation (about 100 cycles)
    li t0, 100
wait_compute:
    addi t0, t0, -1
    bnez t0, wait_compute

    # Check for spikes in all neurons
    li a0, 0
    jal check_spike
    beqz a0, no_spike_0
    # Spike detected in neuron 0 - propagate
    li a0, 0
    li a1, 1                # Destination node (example)
    li a2, 1                # Destination neuron
    li a3, 0x40000000       # Weight = 2.0
    jal propagate_spike

no_spike_0:
    # Check other neurons...
    # (Similar code for neurons 1, 2, 3)

    # Next timestep
    j simulation_timestep

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# =============================================================================
# Inject Current to Neuron
# =============================================================================
# Input: a0 = neuron_id, a1 = current (IEEE 754 float)
inject_current:
    # Calculate neuron address
    li t0, 0x80000000
    slli t1, a0, 5
    add t0, t0, t1

    # Write current to input buffer
    sw a1, 0x18(t0)

    ret


# =============================================================================
# Check Spike Status
# =============================================================================
# Input: a0 = neuron_id
# Output: a0 = 1 if spike, 0 otherwise
check_spike:
    # Calculate neuron address
    li t0, 0x80000000
    slli t1, a0, 5
    add t0, t0, t1

    # Read status register
    lw t1, 0x1C(t0)

    # Check spike bit (bit 0)
    andi a0, t1, 0x01

    ret


# =============================================================================
# Propagate Spike via Network
# =============================================================================
# Input: a0 = source_neuron_id
#        a1 = dest_node_id (Y[7:4], X[3:0])
#        a2 = dest_neuron_id
#        a3 = synaptic_weight (IEEE 754)
propagate_spike:
    addi sp, sp, -4
    sw ra, 0(sp)

    # Build packet: [dest_addr:16][neuron_id:16]
    slli t0, a1, 16         # Dest node in upper 16 bits
    andi t1, a2, 0xFFFF     # Neuron ID in lower 16 bits
    or t0, t0, t1           # t0 = packet address

    # Send via SWNET custom instruction
    # SWNET rs1, rs2, offset
    # rs1 = weight data, rs2 = destination packet
    mv t1, a3               # Weight
    mv t2, t0               # Packet
    
    # Custom instruction encoding (placeholder - actual encoding depends on ISA extension)
    # For now, use pseudo-instruction
    # SWNET t1, t2, 0

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# =============================================================================
# Interrupt Service Routine - Handle Incoming Spikes
# =============================================================================
spike_isr:
    # Save context
    addi sp, sp, -32
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw a0, 24(sp)
    sw a1, 28(sp)

isr_receive_loop:
    # Read packet from network using LWNET
    # LWNET rd, rs1, offset
    # For now, use placeholder
    # LWNET t0, zero, 0      # t0 = received packet

    # Check if packet is valid (network interface provides status)
    # Assume t1 contains valid flag
    beqz t1, isr_done       # No more packets

    # Extract destination neuron from packet (lower 16 bits)
    andi t2, t0, 0xFFFF     # t2 = neuron_id

    # Extract weight from packet data
    # (Simplified - weight would be in separate read)
    li t3, 0x3F800000       # Default weight = 1.0

    # Calculate neuron address
    li t4, 0x80000000
    slli a0, t2, 5
    add t4, t4, a0

    # Read current input
    lw a1, 0x18(t4)

    # Add weight to input (floating point add)
    fadd.s fa0, fa1, ft3    # fa0 = current + weight

    # Store updated input
    fsw fa0, 0x18(t4)

    # Check for more packets
    j isr_receive_loop

isr_done:
    # Restore context
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw a0, 24(sp)
    lw a1, 28(sp)
    addi sp, sp, 32

    # Return from interrupt
    mret


# =============================================================================
# Data Section
# =============================================================================
.section .data

neuron_config:
    .word 0x00000000        # Placeholder for runtime data

synaptic_weights:
    .word 0x3F800000        # 1.0
    .word 0x40000000        # 2.0
    .word 0x3F000000        # 0.5
    .word 0x40400000        # 3.0
