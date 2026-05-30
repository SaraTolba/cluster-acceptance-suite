# for file in ./node*; do
#     # Check which node has Lmod issues
#     if grep -q "UNKNOWN" "$file"; then
#         grep "UNKNOWN" "$file" | head -3
#         echo "========"
#     fi
# done

for file in node*; do
    if [ -s "$file" ]; then 
        echo "Issue with $file"
    fi
done

