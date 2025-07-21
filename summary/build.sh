#!/bin/bash

# Chat2SVG Project Summary LaTeX Build Script
# This script compiles the LaTeX files into PDFs

echo "Building Chat2SVG Project Summary..."

# Check if pdflatex is available
if ! command -v pdflatex &> /dev/null; then
    echo "Error: pdflatex is not installed or not in PATH"
    echo "Please install a LaTeX distribution (e.g., TeX Live, MiKTeX)"
    echo "On macOS: brew install --cask mactex"
    echo "On Ubuntu: sudo apt-get install texlive-full"
    exit 1
fi

# Navigate to the summary directory
cd "$(dirname "$0")"

# Clean previous build files
echo "Cleaning previous build files..."
rm -f *.aux *.log *.toc *.out *.fdb_latexmk *.fls *.synctex.gz

# Function to build a LaTeX file
build_latex() {
    local filename="$1"
    local display_name="$2"
    
    echo "Building $display_name..."
    
    # First pass - generate table of contents
    echo "First pass: Generating table of contents for $display_name..."
    pdflatex -interaction=nonstopmode "$filename.tex" > "${filename}_build.log" 2>&1
    
    # Second pass - finalize cross-references and TOC
    echo "Second pass: Finalizing cross-references for $display_name..."
    pdflatex -interaction=nonstopmode "$filename.tex" > "${filename}_build.log" 2>&1
    
    # Check if PDF was generated successfully
    if [ -f "$filename.pdf" ]; then
        echo "✅ Success! PDF generated: $filename.pdf"
        echo "📄 File size: $(du -h "$filename.pdf" | cut -f1)"
        return 0
    else
        echo "❌ Error: $filename.pdf was not generated"
        echo "Check ${filename}_build.log for error details"
        return 1
    fi
}

# Build summary
build_latex "summary" "Chat2SVG Project Summary"
summary_success=$?

# Clean up auxiliary files
echo "Cleaning up auxiliary files..."
rm -f *.aux *.log *.toc *.out *.fdb_latexmk *.fls *.synctex.gz

# Final status
if [ $summary_success -eq 0 ]; then
    echo "🎉 Build completed successfully!"
    echo "📚 Generated file:"
    echo "  - summary.pdf (Chat2SVG Project Documentation)"
    echo ""
    echo "You can now view the PDF with:"
    echo "  open summary.pdf  # macOS"
    echo "  xdg-open summary.pdf  # Linux"
else
    echo "❌ Build failed"
    echo "Check summary_build.log for detailed error information"
    exit 1
fi 