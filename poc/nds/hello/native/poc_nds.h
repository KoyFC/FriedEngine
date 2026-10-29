#pragma once

extern "C"
{
    void poc_nds_init();
    void poc_nds_report(const char *label);
    void poc_nds_print(const char *text);
    double poc_nds_milliseconds();
    void poc_nds_wait_for_vblank();
}
