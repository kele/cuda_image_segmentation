#include <cstdlib>

#include "segmentation_cpu.hpp"

unsigned colour_count[2][10][10][10];
const unsigned DIVIDER = 25;

void segmentation_cpu(unsigned width, unsigned height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image)
{
    /* TODO: make a histogram */
    for (unsigned y = 0; y < height; y++)
        for (unsigned x = 0; x < width; x++) {
            if (memcmp(image[y*width + x], BACKGR) == 0) {
                
            }
        }

}
