# For the C++ parquet writer to work, it is *essential* that arrow is installed
# at the OS level (not as part of an R package binary) and that the R package
# installer manages to find the system-wide libarrow, which will show up at the
# start of compilation with a message along the lines of "Trying Arrow C++ found
# by pkg-config: /usr/local/Cellar/apache-arrow/16.0.0".
#
# It may also be necessary to set the environment variable
# ARROW_R_WITH_PARQUET="ON" before Arrow is compiled.
#
# If R does not use the same libarrow as cpp11, compilation might be fine but
# afterwards you will get errors like "package or namespace load failed",
# "symbol not found in flat namespace" etc.
#
# See
# https://arrow.apache.org/docs/dev/r/articles/developers/setup.html#arrow-library---r-package-mismatches
# for more details.
#
# After installation, the environment variables PKG_LIBS and PKG_CXXFLAGS must
# be set, on MacOS with homebrew this will look something like this:
#
#   export PKG_CXXFLAGS = "-I/usr/local/Cellar/apache-arrow/16.0.0/include"
#   export PKG_LIBS = "-L/usr/local/Cellar/apache-arrow/16.0.0/lib -larrow"
#
# For frequent use, you can store these environment variables in .Renviron
# (without the `export` command).

library("cpp11")
library("arrow")
library("nanoarrow")

cpp11::cpp_source("src/write_parquet.cpp", cxx_std = 'CXX17', quiet = FALSE)

write_parquet <- function(x, sink, delta_columns, encoding=0) {
  array_stream <- as_nanoarrow_array_stream(x)
  write_parquet_cpp(array_stream, sink, delta_columns, encoding)
}
