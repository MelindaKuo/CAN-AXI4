
#include "can_rx.h"

static volatile uint32_t *g_base = 0;


 //4  = byte offset 
static uint32_t rd(uint32_t off){
    return g_base[off/4];

}



static void wr(uint32_t off, uint32_t val){
    g_base[off/4] = val; 
}




 void can_rx_init(volatile uint32_t *base){
    g_base = base; 

    wr(CAN_RX_STATUS, CAN_RX_STATUS_FRAME_READY | CAN_RX_STATUS_CRC_ERROR | CAN_RX_STATUS_STUFF_ERROR | CAN_RX_STATUS_FORM_ERROR | CAN_RX_STATUS_OVERRUN); 

    wr(CAN_RX_CONTROL, CAN_RX_CONTROL_ENABLE); 
 }


 bool can_rx_poll(can_rx_frame_t *out){

    uint32_t st = rd(CAN_RX_STATUS);


    if((st & CAN_RX_STATUS_FRAME_READY ) == 0){
        return false; 
    }

    uint32_t w = rd(CAN_RX_ID);

    out->id = w&0x7FF; 
    out->rtr = (w>>16)&1; 
    out->ide = (w>>17)&1; 

    uint32_t d = rd(CAN_RX_DLC);

    out->dlc = d & 0xF; 

    if(out->rtr == 1){
        out->len = 0; 
    }
    else if(out->dlc > 8){
        out->len = 8; 
    }
    else{
        out->len = out->dlc;
    }

    uint32_t da0 = rd(CAN_RX_DATA0); 
    out->data[0] = (da0 >>0) & 0xFF; 
    out->data[1] = (da0 >> 8) & 0xFF;
    out->data[2] = (da0>>16) & 0xFF;
    out->data[3] = (da0 >> 24) & 0xFF;


    uint32_t da1 = rd(CAN_RX_DATA1); 
    out->data[4] = (da1>> 0) & 0xFF; 
    out->data[5] = (da1 >> 8) & 0xFF; 
    out->data[6] = (da1 >> 16) & 0xFF; 
    out->data[7] = (da1 >> 24) & 0xFF;
 
    wr(CAN_RX_STATUS, CAN_RX_STATUS_FRAME_READY);

    return true; 

 }

 uint32_t can_rx_status(void){
    return rd(CAN_RX_STATUS);
 }


 void can_rx_clear_status(uint32_t mask){
    wr(CAN_RX_STATUS, mask);
 }


uint32_t can_rx_frame_count(void){
    return rd(CAN_RX_FRAME_COUNT);
}


uint32_t can_rx_error_count(void){
    return rd(CAN_RX_ERROR_COUNT);
}