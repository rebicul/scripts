#!/usr/bin/env python3
"""
Mnemonic Search Script - A utility to search for mnemonic patterns in text
"""

import re
import sys
import os
import argparse
from typing import List, Dict, Tuple, Optional, Generator
import concurrent.futures
import logging
from collections import defaultdict

class MnemonicSearcher:
    def __init__(self, max_cache_size: int = 1000):
        # Common mnemonic patterns for different domains
        self.mnemonic_patterns = {
            'colors': ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'violet'],
            'planets': ['mercury', 'venus', 'earth', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune'],
            'taxonomy': ['kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species'],
            'math_order': ['parentheses', 'exponents', 'multiplication', 'division', 'addition', 'subtraction']
        }
        
        # Cache for performance with size limit
        self._search_cache = {}
        self._max_cache_size = max_cache_size
        
        # Pre-compile regex patterns for better performance
        self._compiled_patterns = {}
        self._compile_patterns()
    def _compile_patterns(self):
        """Pre-compile regex patterns for better performance"""
        for category, patterns in self.mnemonic_patterns.items():
            # Create word boundary patterns to match whole words
            pattern_strings = [rf'\b{re.escape(pattern)}\b' for pattern in patterns]
            # Combine into a single regex with named groups
            combined_pattern = '|'.join(f'(?P<{pattern}>{pattern_string})' 
                                      for pattern, pattern_string in zip(patterns, pattern_strings))
            self._compiled_patterns[category] = re.compile(combined_pattern, re.IGNORECASE)
    
    def _manage_cache(self, key: str, value: any):
        """Manage cache size to prevent memory issues"""
        if len(self._search_cache) >= self._max_cache_size:
            # Remove oldest entry (simple FIFO)
            oldest_key = next(iter(self._search_cache))
            del self._search_cache[oldest_key]
        self._search_cache[key] = value
    
    def search_text(self, text: str, pattern_type: str = 'all') -> List[Dict]:
        """Search for mnemonic patterns in text using optimized regex"""
        # Check cache first
        cache_key = f"{hash(text)}_{pattern_type}"
        if cache_key in self._search_cache:
            return self._search_cache[cache_key]
        
        results = []
        
        if pattern_type == 'all':
            categories_to_search = self.mnemonic_patterns.keys()
        else:
            categories_to_search = [pattern_type] if pattern_type in self.mnemonic_patterns else []
        
        for category in categories_to_search:
            if category not in self._compiled_patterns:
                continue
                
            pattern_regex = self._compiled_patterns[category]
            patterns = self.mnemonic_patterns[category]
            
            for match in pattern_regex.finditer(text):
                # Find which pattern matched
                for i, pattern in enumerate(patterns):
                    if match.group(pattern):
                        results.append({
                            'category': category,
                            'pattern': pattern,
                            'order': i,
                            'matches': [match.start()],
                            'count': 1
                        })
                        break
        
        # Consolidate duplicate pattern matches
        consolidated = defaultdict(lambda: {'matches': [], 'count': 0})
        for result in results:
            key = (result['category'], result['pattern'])
            if key not in consolidated:
                consolidated[key] = {
                    'category': result['category'],
                    'pattern': result['pattern'],
                    'order': result['order'],
                    'matches': [],
                    'count': 0
                }
            consolidated[key]['matches'].extend(result['matches'])
            consolidated[key]['count'] += result['count']
        
        final_results = list(consolidated.values())
        
        # Cache the results
        self._manage_cache(cache_key, final_results)
        return final_results
    
    def search_file(self, filepath: str, pattern_type: str = 'all', chunk_size: int = 8192) -> List[Dict]:
        """Search for mnemonic patterns in a file with memory-efficient reading"""
        try:
            file_size = os.path.getsize(filepath)
            
            # For small files, read all at once
            if file_size < chunk_size * 10:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                return self.search_text(content, pattern_type)
            
            # For large files, read in chunks
            results = []
            overlap_size = 100  # Keep overlap to catch patterns across chunk boundaries
            
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                previous_overlap = ""
                
                while True:
                    chunk = f.read(chunk_size)
                    if not chunk:
                        break
                    
                    # Combine with previous overlap
                    text_to_search = previous_overlap + chunk
                    chunk_results = self.search_text(text_to_search, pattern_type)
                    
                    # Filter out matches from the overlap region to avoid duplicates
                    for result in chunk_results:
                        filtered_matches = [pos for pos in result['matches'] 
                                          if pos >= len(previous_overlap)]
                        if filtered_matches:
                            # Adjust positions to file coordinates
                            result['matches'] = filtered_matches
                            results.append(result)
                    
                    # Keep overlap for next iteration
                    previous_overlap = chunk[-overlap_size:] if len(chunk) > overlap_size else chunk
            
            # Consolidate results
            consolidated = defaultdict(lambda: {'matches': [], 'count': 0})
            for result in results:
                key = (result['category'], result['pattern'])
                if key not in consolidated:
                    consolidated[key] = {
                        'category': result['category'],
                        'pattern': result['pattern'],
                        'order': result['order'],
                        'matches': [],
                        'count': 0
                    }
                consolidated[key]['matches'].extend(result['matches'])
                consolidated[key]['count'] += len(result['matches'])
            
            return list(consolidated.values())
            
        except Exception as e:
            logging.error(f"Error reading file {filepath}: {e}")
            return []
    
    def search_directory(self, directory: str, pattern_type: str = 'all', 
                        file_extensions: List[str] = None, max_workers: int = 4) -> Dict:
        """Search for mnemonic patterns in all files in a directory with concurrent processing"""
        if file_extensions is None:
            file_extensions = ['.txt', '.md', '.py', '.js', '.html', '.css']
        
        # Normalize extensions to lowercase for case-insensitive matching
        file_extensions = [ext.lower() for ext in file_extensions]
        
        # Collect all files to process
        files_to_process = []
        for root, dirs, files in os.walk(directory):
            for file in files:
                file_lower = file.lower()
                if any(file_lower.endswith(ext) for ext in file_extensions):
                    files_to_process.append(os.path.join(root, file))
        
        results = {}
        
        # Process files concurrently
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            future_to_file = {
                executor.submit(self.search_file, filepath, pattern_type): filepath
                for filepath in files_to_process
            }
            
            # Collect results as they complete
            for future in concurrent.futures.as_completed(future_to_file):
                filepath = future_to_file[future]
                try:
                    file_results = future.result()
                    if file_results:
                        results[filepath] = file_results
                except Exception as e:
                    logging.error(f"Error processing file {filepath}: {e}")
        
        return results
    
    def print_results(self, results: List[Dict], show_details: bool = False):
        """Print search results in a formatted way"""
        if not results:
            print("No mnemonic patterns found.")
            return
        
        print(f"Found {len(results)} mnemonic patterns:")
        print("-" * 50)
        
        # Sort results by category and order for consistent output
        sorted_results = sorted(results, key=lambda x: (x['category'], x['order']))
        
        for result in sorted_results:
            print(f"Category: {result['category']}")
            print(f"Pattern: {result['pattern']} (order: {result['order']})")
            print(f"Matches: {result['count']}")
            
            if show_details:
                print(f"Positions: {result['matches']}")
            
            print("-" * 30)
    
    def get_cache_stats(self) -> Dict:
        """Get cache statistics for performance monitoring"""
        return {
            'cache_size': len(self._search_cache),
            'max_cache_size': self._max_cache_size,
            'compiled_patterns': len(self._compiled_patterns)
        }

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
    parser.add_argument('--cache-size', type=int, default=1000, help='Maximum cache size')
    parser.add_argument('--max-workers', type=int, default=4, help='Maximum worker threads for directory search')
    parser.add_argument('--stats', action='store_true', help='Show performance statistics')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], 
                       default='WARNING', help='Set logging level')
    
    args = parser.parse_args()
    
    # Configure logging
    logging.basicConfig(level=getattr(logging, args.log_level), 
                       format='%(asctime)s - %(levelname)s - %(message)s')
    
    searcher = MnemonicSearcher(max_cache_size=args.cache_size)
    
    try:
        if args.directory:
            if not os.path.isdir(args.input):
                print(f"Error: '{args.input}' is not a directory")
                sys.exit(1)
            
            results = searcher.search_directory(args.input, args.type, args.extensions, args.max_workers)
            
            if not results:
                print("No mnemonic patterns found in any files.")
            else:
                total_patterns = sum(len(file_results) for file_results in results.values())
                print(f"Found patterns in {len(results)} files ({total_patterns} total patterns)")
                
                for filepath, file_results in results.items():
                    print(f"\nFile: {filepath}")
                    searcher.print_results(file_results, args.verbose)
        
        elif args.file:
            if not os.path.isfile(args.input):
                print(f"Error: '{args.input}' is not a file")
                sys.exit(1)
            
            results = searcher.search_file(args.input, args.type)
            searcher.print_results(results, args.verbose)
        
        else:
            results = searcher.search_text(args.input, args.type)
            searcher.print_results(results, args.verbose)
        
        if args.stats:
            stats = searcher.get_cache_stats()
            print(f"\nPerformance Statistics:")
            print(f"Cache usage: {stats['cache_size']}/{stats['max_cache_size']}")
            print(f"Compiled patterns: {stats['compiled_patterns']}")
    
    except KeyboardInterrupt:
        print("\nSearch interrupted by user")
        sys.exit(1)
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()