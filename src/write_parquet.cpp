#include <arrow/io/file.h>
#include <arrow/table.h>
#include <arrow/c/bridge.h>
#include <arrow/util/type_fwd.h>
#include <parquet/arrow/writer.h>
#include <cpp11.hpp>
#include <cpp11/strings.hpp>

using namespace cpp11;
using namespace arrow;
using namespace parquet;
using parquet::arrow::WriteTable;

// std::vector<std::string> columns = {"country", "economy", "region"};

// strings columns

[[cpp11::register]]
void write_parquet_cpp(SEXP array_stream_xptr, strings file_paths, strings delta_columns, int encoding) {
  std::string file_path = file_paths[0];
  auto array_stream = reinterpret_cast<struct ArrowArrayStream*>(R_ExternalPtrAddr(array_stream_xptr));
  auto reader = ImportRecordBatchReader(array_stream);
  // NOTE: WriteTable can also take a RecordBatch I think... but not a RecordBatchReader obviously
  auto table = Table::FromRecordBatchReader(reader->get());

  WriterProperties::Builder builder;

  builder.version(ParquetVersion::PARQUET_2_6)
    ->compression(Compression::ZSTD)
    ->compression_level(10);

  // dictionary encoding is already the default
  if (encoding != 2 & encoding != 8) {
    for (int i = 0; i < delta_columns.size(); i++) {
      builder.disable_dictionary(delta_columns[i]);
      builder.encoding(delta_columns[i], Encoding::type(encoding));
    }
  }

  std::shared_ptr<WriterProperties> props = builder.build();
  std::shared_ptr<ArrowWriterProperties> arrow_props = ArrowWriterProperties::Builder().store_schema()->build();

  auto outfile = io::FileOutputStream::Open(file_path).ValueOrDie();
  int chunk_size = 1024 * 1024;
  MemoryPool* memory_pool = default_memory_pool();
  Status status = parquet::arrow::WriteTable(*table->get(), memory_pool, outfile, chunk_size, props, arrow_props);
}
