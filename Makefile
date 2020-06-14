NAME = bip32_template_parse

ifeq (${NUM_WORKERS},)
NUM_WORKERS = 1
endif

all: check

run_check = java -jar ${TLATOOLSDIR}/tla2tools.jar \
		-config ${NAME}.cfg \
		-workers ${NUM_WORKERS} \
		-metadir workdir/meta \
		-terse \
		-cleanup \
		-userFile workdir/output.txt \
		MC.tla

workdir/output.txt: workdir/meta
	$(call run_check,)

workdir/output.txt.uniq: workdir/output.txt
	@uniq workdir/output.txt | sort | uniq > $@

check: workdir/meta
	$(call run_check,)

${NAME}.pdf: workdir/meta
	java -cp ${TLATOOLSDIR}/tla2tools.jar tla2tex.TLA \
	    -metadir workdir/meta \
	    -latexOutputExt pdf \
	    -latexCommand pdflatex \
	    -ptSize 12 \
	    -shade \
	    ${NAME}.tla

pdf: ${NAME}.pdf

test_data: MC.tla workdir/output.txt.uniq
	@python3 generate_test_data.py MC.tla bip32_template_parse.cfg < workdir/output.txt.uniq

clean:
	rm -rf workdir

workdir:
	mkdir -p workdir

workdir/meta:
	mkdir -p workdir/meta

.PHONY: all check pdf clean
