include .Renviron

.PHONY: upload download build

# no sense in uploading the data, when we actually want to data remotely and then download
upload:
	rsync --recursive --verbose --partial --progress --exclude '.*' --exclude 'data/*' --exclude 'renv/*' . ${PISA_BUILD_SERVER}:${PISA_REMOTE_PATH}

# when on wifi, consider that sneakernet is considerably faster
download:
	rsync --recursive --verbose --partial --progress ${PISA_BUILD_SERVER}:${PISA_REMOTE_PATH}/data .

snapshot:
	Rscript -e 'renv::snapshot()'

update: snapshot upload
	ssh ${PISA_BUILD_SERVER} "cd ${PISA_REMOTE_PATH}; Rscript -e 'renv::restore()'"

build:
	ssh ${PISA_BUILD_SERVER} "cd ${PISA_REMOTE_PATH}; Rscript src/preprocess.R"

data:
  wget
