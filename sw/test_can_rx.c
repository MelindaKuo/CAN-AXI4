

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "can_rx.h"


static uint32_t mock_regs[8];

#define REG(off) (mock_regs[(off) / 4])


static void mock_present_frame(uint16_t id, bool rtr, uint8_t dlc, const uint8_t *data, uint8_t len){
    REG(CAN_RX_ID) = (uint32_t) id | ((uint32_t) rtr << 16) | ((uint32_t) 0 <<17);
    uint32_t d0 = 0;
    for(uint8_t i = 0; i< len && i< 4 ; i++){
        d0 |= (uint32_t) data[i] << (8*i);
    }
    uint32_t d1 = 0;
    for(uint8_t k = 4; k< len && k< 8; k++){
        d1 |= (uint32_t) data[k] << (8*(k-4));
    }

    REG(CAN_RX_DATA0) = d0;
    REG(CAN_RX_DATA1) = d1;
    REG(CAN_RX_STATUS)  = CAN_RX_STATUS_FRAME_READY;
    REG(CAN_RX_DLC) = dlc;


}

static int fails = 0;

static void check(const char *what, uint32_t got, uint32_t expected)
{
    if (got != expected) {
        printf("  FAIL  %-26s got 0x%08x  expected 0x%08x\n", what, got, expected);
        fails++;
    }
}

static void fresh(void)
{
    memset(mock_regs, 0, sizeof mock_regs);
    can_rx_init(mock_regs);
    REG(CAN_RX_STATUS) = 0;
}

static const uint8_t bytes5[5] = { 0x00, 0x11, 0x22, 0x33, 0x44 };
static const uint8_t bytes8[8] = { 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 };


static void test_init(void)
{
    printf("TEST 0  init enables the core and acknowledges stale flags\n");

    memset(mock_regs, 0, sizeof mock_regs);
    can_rx_init(mock_regs);

    check("CONTROL enable", REG(CAN_RX_CONTROL) & CAN_RX_CONTROL_ENABLE,
                            CAN_RX_CONTROL_ENABLE);
    check("STATUS acknowledged", REG(CAN_RX_STATUS),
                            CAN_RX_STATUS_FRAME_READY | CAN_RX_STATUS_CRC_ERROR |
                            CAN_RX_STATUS_STUFF_ERROR | CAN_RX_STATUS_FORM_ERROR |
                            CAN_RX_STATUS_OVERRUN);
}

static void test_basic_poll(void)
{
    can_rx_frame_t f;

    printf("TEST 1  a staged frame comes back field for field\n");

    fresh();
    mock_present_frame(0x123, false, 5, bytes5, 5);

    check("poll returned true", can_rx_poll(&f), 1);
    check("id",      f.id,      0x123);
    check("rtr",     f.rtr,     0);
    check("ide",     f.ide,     0);
    check("dlc",     f.dlc,     5);
    check("len",     f.len,     5);
    check("data[0]", f.data[0], 0x00);
    check("data[1]", f.data[1], 0x11);
    check("data[2]", f.data[2], 0x22);
    check("data[3]", f.data[3], 0x33);
    check("data[4]", f.data[4], 0x44);
    check("data[5] unused", f.data[5], 0x00);
    check("data[7] unused", f.data[7], 0x00);
}

static void test_nothing_ready(void)
{
    can_rx_frame_t f, before;

    printf("TEST 2  nothing waiting leaves the caller's frame alone\n");

    fresh();
    memset(&f, 0xAA, sizeof f);
    memcpy(&before, &f, sizeof f);

    check("poll returned false", can_rx_poll(&f), 0);
    check("frame untouched", memcmp(&f, &before, sizeof f) == 0, 1);
}

static void test_release(void)
{
    can_rx_frame_t f;

    printf("TEST 3  the ready flag is released, and nothing else is\n");

    fresh();
    mock_present_frame(0x123, false, 5, bytes5, 5);
    REG(CAN_RX_STATUS) |= CAN_RX_STATUS_OVERRUN;

    can_rx_poll(&f);

    check("wrote only FRAME_READY", REG(CAN_RX_STATUS), CAN_RX_STATUS_FRAME_READY);
}

static void test_length_rules(void)
{
    can_rx_frame_t f;

    printf("TEST 4  the reported length follows the two length rules\n");

    fresh();
    mock_present_frame(0x001, false, 0, NULL, 0);
    can_rx_poll(&f);
    check("dlc 0 -> len", f.len, 0);
    check("dlc 0 -> dlc", f.dlc, 0);

    fresh();
    mock_present_frame(0x002, false, 8, bytes8, 8);
    can_rx_poll(&f);
    check("dlc 8 -> len", f.len, 8);
    check("dlc 8 -> dlc", f.dlc, 8);

    fresh();
    mock_present_frame(0x003, false, 12, bytes8, 8);
    can_rx_poll(&f);
    check("dlc 12 -> len clamps", f.len, 8);
    check("dlc 12 -> dlc is raw", f.dlc, 12);

    fresh();
    mock_present_frame(0x004, true, 5, NULL, 0);
    can_rx_poll(&f);
    check("remote -> len", f.len, 0);
    check("remote -> dlc is raw", f.dlc, 5);
    check("remote -> rtr", f.rtr, 1);
}

static void test_byte_order(void)
{
    can_rx_frame_t f;

    printf("TEST 5  byte 0 is the first byte on the wire\n");

    fresh();
    mock_present_frame(0x7FF, false, 8, bytes8, 8);

    check("mock packed DATA0", REG(CAN_RX_DATA0), 0x33221100u);
    check("mock packed DATA1", REG(CAN_RX_DATA1), 0x77665544u);

    can_rx_poll(&f);

    check("data[0] first", f.data[0], 0x00);
    check("data[3]",       f.data[3], 0x33);
    check("data[4]",       f.data[4], 0x44);
    check("data[7] last",  f.data[7], 0x77);
    check("id 0x7FF",      f.id,      0x7FF);
}

static void test_status_and_counters(void)
{
    printf("TEST 6  status and counters read and clear correctly\n");

    fresh();
    REG(CAN_RX_STATUS) = CAN_RX_STATUS_CRC_ERROR | CAN_RX_STATUS_OVERRUN;
    check("status reads through", can_rx_status(),
          CAN_RX_STATUS_CRC_ERROR | CAN_RX_STATUS_OVERRUN);

    fresh();
    REG(CAN_RX_STATUS) = 0x1F;
    can_rx_clear_status(CAN_RX_STATUS_OVERRUN);
    check("clear writes the mask only", REG(CAN_RX_STATUS), CAN_RX_STATUS_OVERRUN);

    fresh();
    REG(CAN_RX_FRAME_COUNT) = 4242;
    REG(CAN_RX_ERROR_COUNT) = 7;
    check("frame count offset", can_rx_frame_count(), 4242);
    check("error count offset", can_rx_error_count(), 7);
}


int main(void)
{
    test_init();
    test_basic_poll();
    test_nothing_ready();
    test_release();
    test_length_rules();
    test_byte_order();
    test_status_and_counters();

    if (fails == 0) {
        printf("\nDRIVER PASS\n");
        return 0;
    }

    printf("\nDRIVER FAIL  %d check(s) failed\n", fails);
    return 1;
}
