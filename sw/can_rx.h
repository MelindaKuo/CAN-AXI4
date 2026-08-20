

#ifndef CAN_RX_H
#define CAN_RX_H

#include <stdbool.h>
#include <stdint.h>


#define CAN_RX_ID          0x00u   /* RO  [10:0] id, [16] rtr, [17] ide     */
#define CAN_RX_DLC         0x04u   /* RO  [3:0] dlc                          */
#define CAN_RX_DATA0       0x08u   /* RO  bytes 0-3, byte 0 in [7:0]         */
#define CAN_RX_DATA1       0x0Cu   /* RO  bytes 4-7                          */
#define CAN_RX_STATUS      0x10u   /* RO / W1C                               */
#define CAN_RX_CONTROL     0x14u   /* RW  [0] core enable                    */
#define CAN_RX_FRAME_COUNT 0x18u   /* RO                                     */
#define CAN_RX_ERROR_COUNT 0x1Cu   /* RO                                     */


#define CAN_RX_STATUS_FRAME_READY (1u << 0)
#define CAN_RX_STATUS_CRC_ERROR   (1u << 1)
#define CAN_RX_STATUS_STUFF_ERROR (1u << 2)
#define CAN_RX_STATUS_FORM_ERROR  (1u << 3)
#define CAN_RX_STATUS_OVERRUN     (1u << 4)


#define CAN_RX_CONTROL_ENABLE     (1u << 0)



typedef struct {
    uint16_t id;        
    bool     rtr;       
    bool     ide;      
    uint8_t  dlc;      
    uint8_t  len;      
    uint8_t  data[8];
} can_rx_frame_t;




 void can_rx_init(volatile uint32_t *base); 

 bool can_rx_poll(can_rx_frame_t *out); //true when receive frame, false when none was ready 

 uint32_t can_rx_status(void); 
 void can_rx_clear_status (uint32_t mask); 
 uint32_t can_rx_frame_count(void); 
 uint32_t can_rx_error_count(void); 



#endif 
