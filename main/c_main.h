
#include <stdint.h>

// void display_pretty_colors(uint16_t *lines[2]);
void init_spi(uint16_t *lines[2]);
void send_line_finish();

void send_lines(int ypos, uint16_t *linedata);
