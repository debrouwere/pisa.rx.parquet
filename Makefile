include .Renviron

.PHONY: upload download build

# no sense in uploading build artifacts when we actually want to generate them remotely
upload:
	rsync --recursive --verbose --partial --progress --exclude '.*' --exclude 'build/*' --exclude 'renv/*' . ${PISA_BUILD_SERVER}:${PISA_REMOTE_PATH}

# when on wifi, consider that sneakernet is considerably faster
download:
	rsync --recursive --verbose --partial --progress ${PISA_BUILD_SERVER}:${PISA_REMOTE_PATH}/build .

snapshot:
	Rscript -e 'renv::snapshot()'

update: snapshot upload
	ssh ${PISA_BUILD_SERVER} "cd ${PISA_REMOTE_PATH}; Rscript -e 'renv::restore()'"

codebook:
	ssh ${PISA_BUILD_SERVER} "cd ${PISA_REMOTE_PATH}; Rscript src/metadata.R"

build:
	ssh ${PISA_BUILD_SERVER} "cd ${PISA_REMOTE_PATH}; Rscript src/preprocess.R"

data:
	mkdir -p ../pisa.parquet/build
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2000.parquet
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2003.parquet
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2006.parquet
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2009.parquet
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2012.parquet
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2015.parquet
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2018.parquet
	wget -P ../pisa.parquet/build https://github.com/debrouwere/pisa.parquet/releases/download/v2022.1.0/2022.parquet
