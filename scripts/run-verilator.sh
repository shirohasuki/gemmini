#!/bin/bash

ROOT="$PWD/"

help () {
  echo "Run a RISCV Gemmini program on Verilator, a cycle-accurate simulator"
  echo
  echo "Usage: $0 [--pk] [--debug] BINARY"
  echo
  echo "Options:"
  echo " pk      Run binaries on the proxy kernel, which enables virtual memory"
  echo "         and a few syscalls. If this option is not set, binaries will be"
  echo "         run in baremetal mode."
  echo
  echo " debug   Use the debug version of the Verilator simulator, which will"
  echo "         output  a waveform to \`$WAVEFORM\`."
  echo
  echo " BINARY  The RISCV binary that you want to run. This can either be the"
  echo '         name of a program in `software/gemmini-rocc-tests`, or it can'
  echo "         be the full path to a binary you compiled."
  echo
  echo "Examples:"
  echo "         $0 template"
  echo "         $0 --debug template"
  echo "         $0 --pk mvin_mvout"
  echo "         $0 path/to/binary-baremetal"
  echo
  echo 'Note:    Run this command after running `scripts/build-verilator.sh` or'
  echo '         `scripts/build-verilator.sh --debug`.'
  exit
}

if [ $# -le 0 ]; then
    help
fi

pk=0
debug=0
show_help=0
binary=""

while [ $# -gt 0 ] ; do
  case $1 in
    --pk) pk=1 ;;
    --debug) debug=1 ;;
    -h | --help) show_help=1 ;;
    *) binary=$1
  esac

  shift
done

TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
WAVEFORM="waveforms/${TIMESTAMP}-${binary}-waveform.vcd"

if [ $show_help -eq 1 ]; then
   help
fi

if [ $pk -eq 1 ]; then
    default_suffix="-pk"
    PK="pk -p"
else
    default_suffix="-baremetal"
    PK=""
fi

if [ $debug -eq 1 ]; then
    DEBUG="-debug -v ${ROOT}${WAVEFORM}"
else
    DEBUG=""
fi

path=""
suffix=""

for dir in bareMetalC mlps imagenet transformers ; do
    if [ -f "software/gemmini-rocc-tests/build/${dir}/${binary}$default_suffix" ]; then
        path="${ROOT}/software/gemmini-rocc-tests/build/${dir}/"
        suffix=$default_suffix
    fi
done

full_binary_path="${path}${binary}${suffix}"

if [ ! -f "${full_binary_path}" ]; then
    echo "Binary not found: $full_binary_path"
    exit 1
fi

LOG_DIR="${ROOT}/log/${TIMESTAMP}-${binary}-verilator-run-log"
mkdir -p "${LOG_DIR}"

cd ../../sims/verilator/

# ./simulator-chipyard-CustomGemminiSoCConfig${DEBUG} -V $PK ${full_binary_path} \
#     &> >(tee ${LOG_DIR}/stdout.log) \
#     2> >(spike-dasm > ${LOG_DIR}/disasm.log)

/home/shiroha/Code/chipyard/scripts/smartelf2hex.sh ${full_binary_path} > ${full_binary_path}.loadmem_hex
./simulator-chipyard-CustomGemminiSoCConfig${DEBUG} +permissive  \
    +dramsim +dramsim_ini_dir=/home/shiroha/Code/chipyard/generators/testchipip/src/main/resources/dramsim2_ini \
    +loadmem=${full_binary_path}.loadmem_hex +loadmem_addr=80000000 +verbose \
    +permissive-off  ${full_binary_path} \
    &> >(tee ${LOG_DIR}/stdout.log) \
    2> >(spike-dasm > ${LOG_DIR}/disasm.log)
