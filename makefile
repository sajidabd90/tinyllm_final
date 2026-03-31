SIM ?= icarus
TOPLEVEL_LANG ?= verilog
export PYTHONPATH := $(PWD):$(PYTHONPATH)

VERILOG_SOURCES += $(PWD)/q88_weight_rom.v
VERILOG_SOURCES += $(PWD)/transformer_block_fsm.v
VERILOG_SOURCES += $(PWD)/mha_fsm.v
VERILOG_SOURCES += $(PWD)/q88_dot_product.v
VERILOG_SOURCES += $(PWD)/q88_kv_cache.v
VERILOG_SOURCES += $(PWD)/q88_mult.v
VERILOG_SOURCES += $(PWD)/q88_vector_assembler.v
VERILOG_SOURCES += $(PWD)/q88_layernorm_stats.v
VERILOG_SOURCES += $(PWD)/q88_max_finder.v
VERILOG_SOURCES += $(PWD)/q88_sub_shift.v
VERILOG_SOURCES += $(PWD)/q88_softmax_norm.v
VERILOG_SOURCES += $(PWD)/transformer_block.v
VERILOG_SOURCES += $(PWD)/embedding_lookup.v
VERILOG_SOURCES += $(PWD)/q88_weight_row_rom.v
VERILOG_SOURCES += $(PWD)/q88_layernorm_scale.v
VERILOG_SOURCES += $(PWD)/top_level_llm.v

TOPLEVEL = top_level_llm

MODULE = test_task5

include $(shell cocotb-config --makefiles)/Makefile.sim