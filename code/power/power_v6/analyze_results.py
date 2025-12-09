#!/usr/bin/env python3
"""
Power Analysis Visualization and Comparison Tool

Description: Analyzes parametric sweep results and generates visualizations
Usage: python3 analyze_results.py <results_directory>
"""

import os
import sys
import csv
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

def load_results(results_dir):
    """Load power summary CSV file"""
    csv_file = Path(results_dir) / "power_summary.csv"
    if not csv_file.exists():
        print(f"Error: Could not find {csv_file}")
        return None
    
    df = pd.read_csv(csv_file)
    
    # Convert power values to numeric, handling 'N/A'
    power_cols = ['Total_Power(W)', 'Int_Power(W)', 'Switch_Power(W)', 'Leak_Power(W)']
    for col in power_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    
    return df

def create_visualizations(df, output_dir):
    """Create various visualization plots"""
    
    # Set style
    sns.set_style("whitegrid")
    plt.rcParams['figure.figsize'] = (12, 8)
    
    # Filter successful runs only
    df_success = df[df['Status'] == 'SUCCESS'].copy()
    
    if df_success.empty:
        print("Warning: No successful runs to visualize")
        return
    
    # 1. Total Power vs Total Neurons
    plt.figure(figsize=(12, 8))
    for neurons in df_success['Neurons'].unique():
        subset = df_success[df_success['Neurons'] == neurons]
        plt.plot(subset['Total_Neurons'], subset['Total_Power(W)'], 
                marker='o', linewidth=2, markersize=8, 
                label=f'{neurons} neurons/node')
    
    plt.xlabel('Total Neurons in Mesh', fontsize=12)
    plt.ylabel('Total Power (W)', fontsize=12)
    plt.title('Power Consumption vs Total Neurons', fontsize=14, fontweight='bold')
    plt.legend(fontsize=10)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(Path(output_dir) / 'power_vs_neurons.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: power_vs_neurons.png")
    plt.close()
    
    # 2. Power Breakdown by Configuration
    plt.figure(figsize=(14, 8))
    x = range(len(df_success))
    width = 0.25
    
    plt.bar([i - width for i in x], df_success['Int_Power(W)'], 
            width, label='Internal Power', color='#FF6B6B')
    plt.bar(x, df_success['Switch_Power(W)'], 
            width, label='Switching Power', color='#4ECDC4')
    plt.bar([i + width for i in x], df_success['Leak_Power(W)'], 
            width, label='Leakage Power', color='#95E1D3')
    
    plt.xlabel('Configuration', fontsize=12)
    plt.ylabel('Power (W)', fontsize=12)
    plt.title('Power Breakdown by Configuration', fontsize=14, fontweight='bold')
    plt.xticks(x, df_success['Configuration'], rotation=45, ha='right')
    plt.legend(fontsize=10)
    plt.tight_layout()
    plt.savefig(Path(output_dir) / 'power_breakdown.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: power_breakdown.png")
    plt.close()
    
    # 3. Heatmap: Power vs Mesh Size and Neurons
    plt.figure(figsize=(10, 8))
    pivot_table = df_success.pivot_table(
        values='Total_Power(W)', 
        index='Neurons', 
        columns='Rows',
        aggfunc='mean'
    )
    
    sns.heatmap(pivot_table, annot=True, fmt='.4f', cmap='YlOrRd', 
                cbar_kws={'label': 'Total Power (W)'})
    plt.title('Power Consumption Heatmap\n(Mesh Size vs Neurons per Node)', 
              fontsize=14, fontweight='bold')
    plt.xlabel('Mesh Size (NxN)', fontsize=12)
    plt.ylabel('Neurons per Node', fontsize=12)
    plt.tight_layout()
    plt.savefig(Path(output_dir) / 'power_heatmap.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: power_heatmap.png")
    plt.close()
    
    # 4. Power Efficiency: Power per Neuron
    df_success['Power_per_Neuron'] = df_success['Total_Power(W)'] / df_success['Total_Neurons']
    
    plt.figure(figsize=(12, 8))
    mesh_sizes = df_success['Rows'].unique()
    x = range(len(df_success['Neurons'].unique()))
    width = 0.2
    
    for i, size in enumerate(sorted(mesh_sizes)):
        subset = df_success[df_success['Rows'] == size]
        plt.bar([j + i*width for j in x], 
                subset.groupby('Neurons')['Power_per_Neuron'].mean(),
                width, label=f'{size}x{size} mesh')
    
    plt.xlabel('Neurons per Node', fontsize=12)
    plt.ylabel('Power per Neuron (W/neuron)', fontsize=12)
    plt.title('Power Efficiency: Power per Neuron', fontsize=14, fontweight='bold')
    plt.xticks([i + width*1.5 for i in x], sorted(df_success['Neurons'].unique()))
    plt.legend(fontsize=10)
    plt.grid(True, alpha=0.3, axis='y')
    plt.tight_layout()
    plt.savefig(Path(output_dir) / 'power_efficiency.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: power_efficiency.png")
    plt.close()
    
    # 5. Execution Duration
    plt.figure(figsize=(12, 8))
    plt.bar(range(len(df_success)), df_success['Duration(s)'], color='#667BC6')
    plt.xlabel('Configuration', fontsize=12)
    plt.ylabel('Duration (seconds)', fontsize=12)
    plt.title('Synthesis and Analysis Duration', fontsize=14, fontweight='bold')
    plt.xticks(range(len(df_success)), df_success['Configuration'], rotation=45, ha='right')
    plt.grid(True, alpha=0.3, axis='y')
    plt.tight_layout()
    plt.savefig(Path(output_dir) / 'execution_duration.png', dpi=300, bbox_inches='tight')
    print("✓ Generated: execution_duration.png")
    plt.close()

def generate_comparison_table(df, output_dir):
    """Generate detailed comparison table"""
    
    df_success = df[df['Status'] == 'SUCCESS'].copy()
    
    if df_success.empty:
        return
    
    # Calculate power per neuron
    df_success['Power_per_Neuron(mW)'] = (df_success['Total_Power(W)'] / df_success['Total_Neurons']) * 1000
    
    # Select columns for comparison
    comparison_df = df_success[[
        'Configuration', 'Rows', 'Cols', 'Neurons', 'Total_Nodes', 'Total_Neurons',
        'Total_Power(W)', 'Int_Power(W)', 'Switch_Power(W)', 'Leak_Power(W)',
        'Power_per_Neuron(mW)', 'Duration(s)'
    ]].round(6)
    
    # Save to formatted text file
    output_file = Path(output_dir) / 'comparison_table.txt'
    with open(output_file, 'w') as f:
        f.write("="*120 + "\n")
        f.write("POWER ANALYSIS COMPARISON TABLE\n")
        f.write("="*120 + "\n\n")
        f.write(comparison_df.to_string(index=False))
        f.write("\n\n" + "="*120 + "\n")
    
    print(f"✓ Generated: comparison_table.txt")
    
    # Save to Excel if openpyxl is available
    try:
        excel_file = Path(output_dir) / 'comparison_table.xlsx'
        comparison_df.to_excel(excel_file, index=False, sheet_name='Power Analysis')
        print(f"✓ Generated: comparison_table.xlsx")
    except ImportError:
        print("  (Install openpyxl for Excel export: pip install openpyxl)")

def print_statistics(df):
    """Print statistical summary"""
    
    df_success = df[df['Status'] == 'SUCCESS'].copy()
    
    if df_success.empty:
        print("\nNo successful runs to analyze")
        return
    
    print("\n" + "="*60)
    print("STATISTICAL SUMMARY")
    print("="*60)
    
    print(f"\nTotal Configurations Tested: {len(df)}")
    print(f"Successful: {len(df_success)}")
    print(f"Failed: {len(df) - len(df_success)}")
    
    print(f"\nPower Statistics (Successful runs only):")
    print(f"  Minimum Total Power: {df_success['Total_Power(W)'].min():.4f} W")
    print(f"  Maximum Total Power: {df_success['Total_Power(W)'].max():.4f} W")
    print(f"  Average Total Power: {df_success['Total_Power(W)'].mean():.4f} W")
    print(f"  Std Deviation: {df_success['Total_Power(W)'].std():.4f} W")
    
    # Find most/least efficient
    df_success['Power_per_Neuron'] = df_success['Total_Power(W)'] / df_success['Total_Neurons']
    most_efficient = df_success.loc[df_success['Power_per_Neuron'].idxmin()]
    least_efficient = df_success.loc[df_success['Power_per_Neuron'].idxmax()]
    
    print(f"\nMost Efficient Configuration:")
    print(f"  {most_efficient['Configuration']} - {most_efficient['Power_per_Neuron']*1000:.4f} mW/neuron")
    
    print(f"\nLeast Efficient Configuration:")
    print(f"  {least_efficient['Configuration']} - {least_efficient['Power_per_Neuron']*1000:.4f} mW/neuron")
    
    print("\n" + "="*60)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_results.py <results_directory>")
        print("Example: python3 analyze_results.py parametric_results_20251209_123456")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    
    if not os.path.isdir(results_dir):
        print(f"Error: Directory '{results_dir}' not found")
        sys.exit(1)
    
    print("="*60)
    print("Power Analysis Visualization Tool")
    print("="*60)
    print(f"Results Directory: {results_dir}\n")
    
    # Load results
    print("Loading results...")
    df = load_results(results_dir)
    
    if df is None:
        sys.exit(1)
    
    print(f"✓ Loaded {len(df)} configurations\n")
    
    # Print statistics
    print_statistics(df)
    
    # Generate visualizations
    print("\nGenerating visualizations...")
    create_visualizations(df, results_dir)
    
    # Generate comparison table
    print("\nGenerating comparison tables...")
    generate_comparison_table(df, results_dir)
    
    print("\n" + "="*60)
    print("Analysis Complete!")
    print("="*60)
    print(f"\nAll outputs saved in: {results_dir}/")
    print("\nGenerated files:")
    print("  - power_vs_neurons.png")
    print("  - power_breakdown.png")
    print("  - power_heatmap.png")
    print("  - power_efficiency.png")
    print("  - execution_duration.png")
    print("  - comparison_table.txt")
    print("  - comparison_table.xlsx (if openpyxl available)")

if __name__ == "__main__":
    main()
