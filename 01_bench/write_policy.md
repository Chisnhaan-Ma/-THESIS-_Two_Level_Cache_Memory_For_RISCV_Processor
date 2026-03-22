# Write Policy: flow ghi từ LSU đến SDRAM

## 1. Mục tiêu

Tài liệu này mô tả luồng ghi dữ liệu khi CPU thực hiện lệnh store, bắt đầu từ LSU, đi qua L1 cache, L2 cache và cuối cùng xuống bộ nhớ nền. Trong code hiện tại, bộ nhớ nền đang là `sram.sv` với handshake kiểu SRAM đơn giản. Module `sdram_controler.sv` được thiết kế cùng giao diện, nên có thể xem đây là bước cuối tương thích để thay `sram.sv` bằng SDRAM controller.

## 2. Các khối tham gia vào flow ghi

### 2.1 `memory_cycle.sv`

- Nhận thông tin store từ Execute stage.
- Xác định đây có phải truy cập memory hay không bằng opcode load/store.
- Đưa địa chỉ ALU, dữ liệu `rs2`, tín hiệu write enable xuống LSU.
- Giữ request trong lúc cache đang stall để transaction không bị mất giữa chừng.

Các tín hiệu quan trọng:

- `i_mem_lsu_wren`: store enable.
- `i_mem_alu_data`: địa chỉ truy cập.
- `i_mem_rs2_data`: dữ liệu store gốc.
- `internal_stall`: LSU/cache đang bận xử lý request.

### 2.2 `lsu_new.sv`

- Phân loại truy cập là data memory hay I/O mapped peripheral.
- Tạo `byte_mask` theo loại lệnh `SB/SH/SW`.
- Căn chỉnh dữ liệu store thành dạng 32-bit để ghi vào cache.
- Gửi request xuống L1 cache (`cache_v2`).

Hai khối quan trọng trong store path:

- `mask_create`: tạo `byte_mask`.
- `mask_store`: đặt dữ liệu store vào đúng byte lane trong word 32-bit.

Ví dụ:

- `SB` tại offset `2'b10` sẽ tạo `byte_mask = 4'b0100`.
- Dữ liệu store được dời vào bit `[23:16]` trước khi đưa xuống cache.

### 2.3 `cache_v2.sv` (L1 cache)

L1 đang dùng chính sách:

- `write-back`: khi write hit thì chỉ cập nhật line trong cache và set `dirty = 1`, chưa ghi ngay xuống L2.
- `write-allocate`: khi write miss thì vẫn nạp line về cache trước, sau đó mới merge dữ liệu store vào line mới.
- Thay thế line theo FIFO bằng `fifo_ptr`.

### 2.4 `cache_l2.sv` / `cache_l2_v2.sv` (L2 cache)

Vai trò của L2:

- Nhận request writeback hoặc allocate từ L1.
- Nếu L2 hit: xử lý trên line của L2.
- Nếu L2 miss: có thể phải writeback victim line xuống backing memory rồi mới allocate line mới.

Trong biến thể `cache_l2_v2.sv`, data array của L2 nằm trên SRAM IS61 ngoài chip, nên trước khi writeback một victim dirty line, L2 phải đọc line đó ra khỏi SRAM ngoài trước.

### 2.5 `sram.sv` / `sdram_controler.sv`

- `sram.sv`: backend hiện tại trong code, giao tiếp đơn giản, `o_ready` lên sau 1 chu kỳ kể từ khi `i_sram_enb` được bật.
- `sdram_controler.sv`: backend tương thích cùng handshake, nhưng bên trong sẽ biến 1 transaction 32-bit thành 2 lần truy cập SDRAM 16-bit.

## 3. Write policy tổng quát

### 3.1 Chính sách ở L1

L1 sử dụng:

- Write hit: cập nhật line ngay tại L1, set dirty.
- Write miss + victim clean hoặc invalid: không cần writeback, đi allocate line mới từ L2.
- Write miss + victim dirty: phải writeback victim xuống L2 trước, sau đó allocate line mới, rồi merge dữ liệu store.

Nói ngắn gọn:

- Hit: sửa tại chỗ.
- Miss: lấy line về trước rồi mới ghi.
- Dirty victim: đẩy line cũ đi trước khi thay thế.

### 3.2 Chính sách ở L2

L2 cũng đi theo cùng tinh thần:

- Write-back.
- Write-allocate.
- Dirty victim phải writeback xuống backing memory.

Khác biệt lớn là nếu dùng `cache_l2_v2.sv`, data của L2 nằm trong SRAM ngoài, nên dirty victim không có sẵn trong thanh ghi nội bộ. L2 phải đọc line đó từ SRAM ngoài rồi mới có dữ liệu để ghi xuống backend.

## 4. Flow store end-to-end trong code hiện tại

## Bước 1: instruction store đi vào Memory stage

Trong `memory_cycle.sv`:

- `mem_access = 1` nếu opcode là `LOAD` hoặc `STORE`.
- Với store, `i_mem_lsu_wren = 1`.
- Địa chỉ store là `i_mem_alu_data`.
- Dữ liệu store là `i_mem_rs2_data`.

Nếu cache chưa xử lý xong, `internal_stall = 1`, pipeline giữ request lại.

## Bước 2: LSU chuẩn bị request ghi

Trong `lsu_new.sv`:

1. `demux_sel_mem` kiểm tra đây có phải truy cập data memory không.
2. `mask_create` sinh `byte_mask` theo `SB/SH/SW`.
3. `mask_store` dời dữ liệu store vào đúng byte lane trong word 32-bit.
4. L1 cache nhận:
   - `i_mem_access`
   - `i_wr_en`
   - `i_addr`
   - `i_byte_mask`
   - `i_wdata`

## Bước 3: L1 xử lý request ghi

Trong `cache_v2.sv`:

### Trường hợp A: write hit ở L1

State flow:

`IDLE -> LOOKUP -> RESPONE -> IDLE`

Tại `LOOKUP` nếu `hit = 1` và `req_wr_en_reg = 1`:

- `data_array[index][hit_way] <= write_with_mask(...)`
- `dirty[index][hit_way] <= 1`

Ý nghĩa:

- Dữ liệu chỉ được cập nhật ở L1.
- Chưa ghi xuống L2 ngay.
- Đây chính là write-back.

### Trường hợp B: write miss, victim clean hoặc invalid

State flow:

`IDLE -> LOOKUP -> ALLOCATE -> REFILL -> RESPONE -> IDLE`

Ý nghĩa:

1. L1 gửi yêu cầu đọc line tương ứng xuống L2 qua:
   - `o_cache_l2_enb = 1`
   - `o_cache_l2_addr = miss_addr_reg`
   - `o_cache_l2_wr_en = 0`
2. Khi L2 trả về `i_cache_l2_rdata` và `i_cache_l2_ready`:
   - line mới được ghi vào victim way
   - dữ liệu store được merge bằng `write_with_mask(...)`
   - `dirty` của line mới được set lên `1`

Ý nghĩa: write miss nhưng vẫn allocate line mới trước khi ghi, nên đây là write-allocate.

### Trường hợp C: write miss, victim dirty

State flow:

`IDLE -> LOOKUP -> WRITEBACK -> ALLOCATE -> REFILL -> RESPONE -> IDLE`

Ý nghĩa:

1. Ở `LOOKUP`, nếu victim line đang `valid && dirty`, L1 chưa được phép ghi đè ngay.
2. L1 đẩy victim line xuống L2 qua:
   - `o_cache_l2_enb = 1`
   - `o_cache_l2_addr = victim_addr_reg`
   - `o_cache_l2_wr_en = 1`
   - `o_cache_l2_wdata = data_array[miss_index_reg][victim_way_reg]`
3. Khi L2 báo `ready`, L1 mới chuyển sang `ALLOCATE` để lấy line mới.
4. Sau khi refill xong, L1 merge dữ liệu store vào line mới và set `dirty = 1`.

## 5. Flow bên trong L2

## 5.1 Nếu dùng `cache_l2.sv`

Về mặt chính sách, L2 xử lý tương tự L1:

- Hit: xử lý trực tiếp trong L2.
- Miss + clean victim: allocate từ backend.
- Miss + dirty victim: writeback xuống backend rồi allocate.

## 5.2 Nếu dùng `cache_l2_v2.sv`

Biến thể này quan trọng hơn vì data array không nằm trong register mà nằm trên chip SRAM ngoài IS61.

Do đó khi L2 gặp `miss + dirty victim`, flow sẽ là:

`LOOKUP -> RD_LO -> RD_HI -> RD_END -> WRITEBACK -> ALLOCATE -> REFILL -> WR_LO -> WR_HI -> RESP`

Giải thích:

1. `LOOKUP`
   - Kiểm tra tag.
   - Nếu miss và victim line dirty, chưa thể writeback ngay vì dữ liệu victim vẫn đang nằm trong SRAM ngoài.

2. `RD_LO` và `RD_HI`
   - Đọc 2 halfword 16-bit của victim line từ IS61 SRAM.

3. `RD_END`
   - Ghép lại thành word 32-bit trong `line_data_reg`.
   - Lưu sang `victim_data_reg`.

4. `WRITEBACK`
   - Lúc này mới có thể ghi `victim_data_reg` xuống backing memory qua `o_sram_*`.

5. `ALLOCATE`
   - Yêu cầu backend trả line mới theo `req_addr_reg`.

6. `REFILL`
   - Chuẩn bị line mới.
   - Nếu request gốc là write, merge dữ liệu store vào `i_sram_rdata` để tạo `write_word_reg`.

7. `WR_LO`, `WR_HI`
   - Ghi line mới vào SRAM ngoài IS61.
   - Cập nhật `tag_array`, `valid`, `dirty`.

Điểm quan trọng:

- L2 không thể nhảy thẳng từ `LOOKUP` sang `WRITEBACK` khi victim dirty.
- Lý do là chưa có dữ liệu victim trong register; cần đọc từ IS61 trước.

## 5.3 Write flow chi tiết riêng của `cache_l2_v2.sv`

Mục này chỉ tập trung vào request ghi (`i_req_wr_en = 1`) tại L2.

### Case A: write hit ở L2

State flow:

`IDLE -> LOOKUP -> RD_LO -> RD_HI -> RD_END -> WR_LO -> WR_HI -> RESP -> IDLE`

Giải thích theo từng nhịp chính:

1. `LOOKUP`
   - Tìm way hit theo tag.
   - `hit_on_req_reg = 1`, `selected_way_reg = hit_way`.
2. `RD_LO`, `RD_HI`
   - Đọc line cũ từ IS61 SRAM ngoài vào `line_data_reg`.
3. `RD_END`
   - Merge dữ liệu store bằng `write_with_mask(line_data_reg, req_wdata_reg, req_byte_mask_reg)`.
   - Kết quả đặt vào `write_word_reg`.
4. `WR_LO`, `WR_HI`
   - Ghi lại word mới vào IS61 SRAM ngoài.
   - Set `dirty[req_index][selected_way_reg] = 1`.
5. `RESP`
   - Hoàn tất transaction, không cần trả data cho read.

Ý nghĩa chính sách:

- Write-back: chỉ cập nhật line tại L2, chưa ghi ngay xuống backend.

### Case B: write miss, victim clean hoặc invalid

Điều kiện ở `LOOKUP`:

- miss và không thỏa `valid && dirty` tại victim.

State flow:

`IDLE -> LOOKUP -> ALLOCATE -> REFILL -> WR_LO -> WR_HI -> RESP -> IDLE`

Giải thích:

1. `ALLOCATE`
   - Gửi read request xuống backend (`o_sram_wr_en = 0`) để lấy line chứa địa chỉ mới.
2. `REFILL`
   - Nhận `i_sram_rdata`.
   - Vì là write request, L2 merge store data ngay trên line refill để tạo `write_word_reg`.
3. `WR_LO`, `WR_HI`
   - Ghi line đã merge vào IS61 SRAM ngoài.
   - Cập nhật metadata:
     - `tag_array = req_tag`
     - `valid = 1`
     - `dirty = 1` (vì request là write)
     - tăng `fifo_ptr`.

Ý nghĩa chính sách:

- Write-allocate: miss vẫn nạp line mới rồi mới ghi.

### Case C: write miss, victim dirty

Điều kiện ở `LOOKUP`:

- miss và `valid[req_index][victim_way] && dirty[req_index][victim_way]`.

State flow:

`IDLE -> LOOKUP -> RD_LO -> RD_HI -> RD_END -> WRITEBACK -> ALLOCATE -> REFILL -> WR_LO -> WR_HI -> RESP -> IDLE`

Giải thích:

1. `LOOKUP`
   - Chọn `victim_way`, lưu `victim_addr_reg`.
2. `RD_LO`, `RD_HI`, `RD_END`
   - Đọc dữ liệu victim từ IS61 SRAM ngoài và ghép thành `victim_data_reg`.
   - Đây là bước bắt buộc trước writeback.
3. `WRITEBACK`
   - Ghi `{victim_addr_reg, victim_data_reg}` xuống backend (`o_sram_wr_en = 1`).
4. `ALLOCATE`
   - Đọc line mới từ backend (`o_sram_wr_en = 0`).
5. `REFILL` + `WR_LO/WR_HI`
   - Merge dữ liệu store của request hiện tại vào line refill.
   - Ghi line mới vào IS61 và cập nhật metadata như Case B.

Ý nghĩa chính sách:

- Dirty victim phải được đẩy xuống tầng dưới trước khi thay thế.
- Vì data array nằm trên SRAM ngoài, phải đọc victim ra trước mới writeback được.

### Tín hiệu mấu chốt để debug write flow ở `cache_l2_v2.sv`

- `hit_on_req_reg`: phân nhánh hit hay miss sau `LOOKUP`.
- `write_word_reg`: word 32-bit cuối cùng sẽ được ghi vào IS61.
- `write_from_refill_reg`: phân biệt write do refill hay write do hit-update.
- `victim_data_reg`: dữ liệu victim dùng cho `WRITEBACK`.
- `selected_way_reg`: way mục tiêu cho đọc/ghi line.
- `o_sram_wr_en`: `1` khi writeback victim, `0` khi allocate line mới.

## 6. Flow từ L2 xuống backend memory

Giao diện giữa L2 và backend là:

- `o_sram_enb`: valid transaction.
- `o_sram_addr`: địa chỉ word 32-bit.
- `o_sram_wr_en`: `1` là write, `0` là read.
- `o_sram_wdata`: dữ liệu ghi.
- `i_sram_rdata`: dữ liệu đọc trả về.
- `i_sram_ready`: backend hoàn tất transaction.

### 6.1 Backend hiện tại: `sram.sv`

Với backend hiện tại:

- Nếu `i_sram_enb=1` và `i_wr_en=1`: ghi `i_wdata` vào mảng nhớ.
- `o_ready` lên sau 1 chu kỳ.
- Đọc là kiểu combinational, nhưng transaction vẫn hoàn tất theo handshake `o_ready`.

### 6.2 Backend đích: `sdram_controler.sv`

Khi thay backend bằng SDRAM controller, giao diện phía trên không đổi. Bên trong controller:

1. Nhận request 32-bit tại `S_IDLE`.
2. Chuyển địa chỉ byte thành 2 địa chỉ halfword 16-bit.
3. Với write 32-bit:
   - half dưới được ghi trước
   - half trên được ghi sau
4. Mỗi half đi qua chuỗi:
   - `S_ACTIVATE`
   - `S_TRCD_WAIT`
   - `S_RW_CMD` với lệnh WRITE
   - `S_PRE_WAIT`
5. Sau khi ghi xong cả 2 halfword:
   - `S_DONE`
   - `o_ready` pulse lên 1 chu kỳ

Nghĩa là từ góc nhìn L2, SDRAM controller vẫn chỉ là một backend có handshake `enb/addr/wr_en/wdata/ready`, nhưng độ trễ bên trong dài hơn nhiều so với `sram.sv`.

## 7. Ví dụ luồng store word hoàn chỉnh

Ví dụ CPU thực hiện `SW x5, 0(x10)`:

1. Execute tạo địa chỉ hiệu dụng tại `i_mem_alu_data`.
2. `memory_cycle.sv` chuyển request xuống LSU.
3. `lsu_new.sv` tạo:
   - `byte_mask = 4'b1111`
   - `st_cache_data = i_st_data`
4. L1 cache nhận request write.

Nếu L1 hit:

- update line tại L1
- set dirty
- kết thúc, chưa xuống L2/SDRAM

Nếu L1 miss, victim clean:

- L1 allocate từ L2
- merge dữ liệu store
- set dirty

Nếu L1 miss, victim dirty:

- L1 writeback victim xuống L2
- L1 allocate line mới từ L2
- L1 merge dữ liệu store

Nếu L2 cũng miss và victim L2 dirty:

- L2 đọc victim từ SRAM ngoài
- L2 writeback victim xuống backend
- L2 allocate line mới từ backend
- L2 ghi line mới vào SRAM ngoài
- L2 trả dữ liệu refill cho L1
- L1 hoàn tất merge store và set dirty

Nếu backend là SDRAM controller:

- backend sẽ ghi xuống SDRAM thật theo 2 lần ghi 16-bit cho mỗi word 32-bit.

## 8. Kết luận

Write policy toàn hệ thống hiện tại là:

- L1: write-back, write-allocate.
- L2: write-back, write-allocate.
- Dirty victim ở mỗi tầng phải được đẩy xuống tầng dưới trước khi thay thế.
- Với `cache_l2_v2.sv`, dirty victim của L2 phải được đọc ra khỏi SRAM ngoài trước khi writeback.
- `sdram_controler.sv` có thể thay `sram.sv` mà không cần đổi handshake với L2, chỉ khác ở số chu kỳ xử lý bên trong.

## 9. Tóm tắt một dòng

Store đi theo nguyên tắc: LSU tạo mask và dữ liệu đã căn chỉnh, L1 ưu tiên ghi tại chỗ nếu hit, nếu miss thì writeback victim dirty rồi allocate line mới, L2 làm tương tự, và tầng backend cuối cùng có thể là SRAM mô phỏng hoặc SDRAM controller dùng cùng handshake.

## 10. Replacement policy: mô tả và flow

## 10.1 Chính sách đang dùng

Hệ thống đang dùng FIFO theo từng set ở cả L1 và L2:

- Mỗi set có một con trỏ fifo_ptr.
- Khi cần thay thế line, victim_way = fifo_ptr tại set tương ứng.
- Sau khi refill thành công line mới, fifo_ptr tăng 1 để trỏ sang way kế tiếp.

Điểm quan trọng:

- Đây là FIFO, không phải LRU.
- Hit không làm thay đổi thứ tự thay thế.
- Chỉ khi thay line thành công thì fifo_ptr mới dịch chuyển.

## 10.2 Flow chọn victim (chung cho mỗi cache level)

1. Nhận request và tách index, tag.
2. So sánh tag trên toàn bộ way trong set.
3. Nếu hit: không replacement, kết thúc theo read/write hit path.
4. Nếu miss: chọn victim_way từ fifo_ptr của set đó.
5. Kiểm tra trạng thái victim:
    - invalid hoặc clean: đi allocate ngay.
    - dirty: phải writeback rồi mới allocate.
6. Refill line mới vào victim_way.
7. Cập nhật metadata và tăng fifo_ptr.

## 10.3 Sơ đồ flow replacement ở L1

START
   |
   v
LOOKUP (set=index)
   |
   +--> Hit? -- Yes --> No replacement -> Done
   |
   No
   |
   v
victim_way = fifo_ptr[index]
   |
   v
victim valid && dirty ?
   |
   +--> Yes --> WRITEBACK to L2 --> wait ready
   |
   +--> No  --> skip writeback
   |
   v
ALLOCATE from L2 --> wait ready
   |
   v
REFILL victim_way, update tag/valid/dirty
   |
   v
fifo_ptr[index] = fifo_ptr[index] + 1
   |
   v
Done

Ghi chú L1:

- Trong trường hợp write miss, dữ liệu store sẽ được merge vào line refill trước khi commit line mới.

## 10.4 Sơ đồ flow replacement ở L2 phiên bản cache_l2_v2

START
   |
   v
LOOKUP (set=index)
   |
   +--> Hit? -- Yes --> No replacement -> Done
   |
   No
   |
   v
victim_way = fifo_ptr[index]
   |
   v
victim valid && dirty ?
   |
   +--> Yes --> RD_LO -> RD_HI -> RD_END (đọc victim từ SRAM IS61)
   |            |
   |            v
   |          WRITEBACK to backend --> wait ready
   |
   +--> No  --> skip read victim, skip writeback
   |
   v
ALLOCATE from backend --> wait ready
   |
   v
REFILL prepare line mới (merge store nếu là write miss)
   |
   v
WR_LO -> WR_HI (ghi vào SRAM IS61)
   |
   v
update tag/valid/dirty
   |
   v
fifo_ptr[index] = fifo_ptr[index] + 1
   |
   v
Done

Điểm khác biệt cốt lõi của L2 v2:

- Victim data nằm trên SRAM ngoài nên dirty victim phải đọc ra trước rồi mới writeback.
- Vì vậy flow replacement của L2 v2 dài hơn L1.

## 10.5 Công thức cập nhật con trỏ FIFO

Với số way là NUM_WAY, con trỏ thay thế của từng set cập nhật theo vòng:

next_fifo_ptr = (fifo_ptr + 1) mod NUM_WAY

Ý nghĩa:

- Mỗi lần thay line thành công, quyền bị thay thế chuyển sang way kế tiếp.
- Đảm bảo phân bố thay thế đều giữa các way trong cùng set.