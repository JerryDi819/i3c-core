class i3c_broadcast_followed_by_data_with_rstart_seq extends i3c_direct_data_seq;
  `uvm_object_utils(i3c_broadcast_followed_by_data_with_rstart_seq)
  `uvm_object_new

  int num_trans;
  int curr_trans;

  constraint transfer_i3c_end_c {
    if (curr_trans < num_trans-1)
      transfer.end_with_rstart dist {1 := 7, 0 := 3};
    else
      transfer.end_with_rstart == 0;
  }

  virtual task send_host_mode_txn();
    // get seq for agent running in Host mode
    curr_trans = 0;
    while (curr_trans < num_trans) begin
      req = i3c_seq_item::type_id::create("req");
      start_item(req);
      req.is_daa = 0;
      req.i3c = 1;
      req.addr = 7'h7E;
      req.dir = 0;
      req.end_with_rstart = 1;
      req.IBI = 0;
      req.IBI_ACK = 0;
      req.IBI_ADDR = 0;
      req.IBI_START = 0;
      `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
      finish_item(req);
      get_response(rsp);
      `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)
      req = i3c_seq_item::type_id::create("req");
      start_item(req);
      req.i3c = 1;
      req.dev_ack = 0;
      if (rsp.dev_ack == 1) begin
        req.end_with_rstart = 1;
        `uvm_info(get_full_name(), $sformatf("\n%s", req.sprint()), UVM_DEBUG)
        finish_item(req);
        get_response(rsp);
        `uvm_info(get_full_name(), $sformatf("\n%s", rsp.sprint()), UVM_DEBUG)

        `uvm_info(get_full_name(), $sformatf("\nNumber of transactions: %d", num_trans), UVM_LOW)
        for (; curr_trans < num_trans; curr_trans++) begin
          host_direct_phase();
          `uvm_info(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()), UVM_LOW)
          if (transfer.end_with_rstart == 0) begin
            curr_trans++;
            break;
          end
        end
      end else begin
        req.end_with_rstart = 0;
        `uvm_error(get_full_name(), $sformatf("\nHost recived:\n%s", rsp.sprint()))
        finish_item(req);
        get_response(rsp);
      end
    end
  endtask

  virtual task seq_stop();
    stop = 1'b1;
    wait_for_sequence_state(UVM_FINISHED);
  endtask : seq_stop

endclass : i3c_broadcast_followed_by_data_with_rstart_seq
