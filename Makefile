docs.json: init.lua
	hs -c "hs.doc.builder.genJSON(\"${CURDIR}\")" | grep -v "^--" > $@ || rm -f $@
