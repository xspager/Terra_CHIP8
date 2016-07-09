//#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <caca.h>

int main(void)
{
    uint32_t gfx[64*32];
    //                   R G B A
    uint32_t pattern = 0xFFFF00FF;

    memset_pattern4(gfx, &pattern, sizeof(gfx));

    gfx[0] =    0xFF0000FF; // R
    gfx[1] =    0x00FF00FF; // G
    gfx[2] =    0x0000FFFF; // B
    gfx[63] =   0xFF0000FF; // R
    gfx[64*31] =0x00FF00FF; // G
    int x = 64, y = 32;
    gfx[(y-1)*64+(x-1)] = 0x0000FFFF; // B

    caca_canvas_t *cv; caca_display_t *dp; caca_event_t ev;
    dp = caca_create_display(NULL);
    if(!dp)
        return 1;
    /*
    printf("Current driver: %s\n", caca_get_display_driver(dp));
    char **drivers = caca_get_display_driver_list();
    caca_free_display(dp);
    while(*drivers != NULL) {
        printf("%s\n", *drivers);
        drivers++;
    }
    exit(0);*/
    cv = caca_get_canvas(dp);
    caca_dither_t *dither = caca_create_dither(32, 64, 32, 4*64,
        0xFF000000,
        0x00FF0000,
        0x0000FF00,
        0x000000FF);
    int cw = caca_get_canvas_width(cv);
    int ch = caca_get_canvas_height(cv);
    caca_set_display_title(dp, "Hello!");
    //caca_set_color_ansi(cv, CACA_BLUE, CACA_WHITE);
    //caca_put_str(cv, 0, 0, "This is a message");
    caca_dither_bitmap(cv, 0,0,cw,ch, dither, gfx);
    caca_refresh_display(dp);

    caca_get_event(dp, CACA_EVENT_KEY_PRESS, &ev, -1);
    caca_free_display(dp);
    return 0;
}
