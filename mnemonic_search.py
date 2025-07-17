#!/usr/bin/env python3
"""
Mnemonic Search Script - A utility to search for mnemonic patterns in text
"""

import re
import sys
import os
import argparse
from typing import List, Dict, Tuple, Optional

class MnemonicSearcher:
    def __init__(self):
        # Common mnemonic patterns for different domains
        self.mnemonic_patterns = {
            'colors': ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'violet'],
            'planets': ['mercury', 'venus', 'earth', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune'],
            'taxonomy': ['kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species'],
            'math_order': ['parentheses', 'exponents', 'multiplication', 'division', 'addition', 'subtraction']
        }
        
        # Cache for performance
        self._search_cache = {}
        
    def search_text(self, text: str, pattern_type: str = 'all') -> List[Dict]:
        """Search for mnemonic patterns in text"""
        results = []
        
        # Check cache first
        cache_key = f"{hash(text)}_{pattern_type}"
        if cache_key in self._search_cache:
            return self._search_cache[cache_key]
        
        text_lower = text.lower()
        
        if pattern_type == 'all':
            patterns_to_search = self.mnemonic_patterns
        else:
            patterns_to_search = {pattern_type: self.mnemonic_patterns.get(pattern_type, [])}
        
        for category, patterns in patterns_to_search.items():
            for i, pattern in enumerate(patterns):
                # Simple substring search (inefficient)
                matches = []
                start = 0
                while True:
                    pos = text_lower.find(pattern.lower(), start)
                    if pos == -1:
                        break
                    matches.append(pos)
                    start = pos + 1
                
                if matches:
                    results.append({
                        'category': category,
                        'pattern': pattern,
                        'order': i,
                        'matches': matches,
                        'count': len(matches)
                    })
        
        # Cache the results
        self._search_cache[cache_key] = results
        return results
    
    def search_file(self, filepath: str, pattern_type: str = 'all') -> List[Dict]:
        """Search for mnemonic patterns in a file"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            return self.search_text(content, pattern_type)
        except Exception as e:
            print(f"Error reading file {filepath}: {e}")
            return []
    
    def search_directory(self, directory: str, pattern_type: str = 'all', file_extensions: List[str] = None) -> Dict:
        """Search for mnemonic patterns in all files in a directory"""
        if file_extensions is None:
            file_extensions = ['.txt', '.md', '.py', '.js', '.html', '.css']
        
        results = {}
        
        for root, dirs, files in os.walk(directory):
            for file in files:
                if any(file.endswith(ext) for ext in file_extensions):
                    filepath = os.path.join(root, file)
                    file_results = self.search_file(filepath, pattern_type)
                    if file_results:
                        results[filepath] = file_results
        
        return results
    
    def print_results(self, results: List[Dict], show_details: bool = False):
        """Print search results in a formatted way"""
        if not results:
            print("No mnemonic patterns found.")
            return
        
        print(f"Found {len(results)} mnemonic patterns:")
        print("-" * 50)
        
        for result in results:
            print(f"Category: {result['category']}")
            print(f"Pattern: {result['pattern']} (order: {result['order']})")
            print(f"Matches: {result['count']}")
            
            if show_details:
                print(f"Positions: {result['matches']}")
            
            print("-" * 30)

def main():
    parser = argparse.ArgumentParser(description='Search for mnemonic patterns in text or files')
    parser.add_argument('input', help='Input text, file path, or directory path')
    parser.add_argument('-t', '--type', choices=['all', 'colors', 'planets', 'taxonomy', 'math_order'], 
                       default='all', help='Type of mnemonic pattern to search for')
    parser.add_argument('-f', '--file', action='store_true', help='Treat input as file path')
    parser.add_argument('-d', '--directory', action='store_true', help='Treat input as directory path')
    parser.add_argument('-v', '--verbose', action='store_true', help='Show detailed results')
    parser.add_argument('-e', '--extensions', nargs='+', default=['.txt', '.md', '.py', '.js', '.html', '.css'],
                       help='File extensions to search (for directory mode)')
    
    args = parser.parse_args()
    
    searcher = MnemonicSearcher()
    
    if args.directory:
        results = searcher.search_directory(args.input, args.type, args.extensions)
        for filepath, file_results in results.items():
            print(f"\nFile: {filepath}")
            searcher.print_results(file_results, args.verbose)
    elif args.file:
        results = searcher.search_file(args.input, args.type)
        searcher.print_results(results, args.verbose)
    else:
        results = searcher.search_text(args.input, args.type)
        searcher.print_results(results, args.verbose)

if __name__ == '__main__':
    main()