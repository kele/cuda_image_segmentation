#include <cstdio>
#include <cstring>

#include "cpu_utils.hpp"

#define MAX_HEIGHT 1000
#define MAX_WIDTH  1000

pixel_t image[MAX_HEIGHT][MAX_WIDTH];
pixel_t marked_image[MAX_HEIGHT][MAX_WIDTH];


int main(int argc, char *argv[])
{
    if (argc != 2)
        return RETERR(1, "Usage: flow image.ppm");

    const char *filename = argv[1];
    char new_filename[strlen(filename) + 1];
    strcpy(&new_filename[1], filename);
    new_filename[0] = '_';

    unsigned width, height;

    if (readppm(filename, &width, &height, (pixel_t *)image))
        return RETERR(1, "Cannot open input file.\n");
    normalize_image(width, height, (pixel_t *)image);
    if (writeppm(new_filename, width, height, (pixel_t *)image))
        return RETERR(1, "Cannot write to %s\n", new_filename);
    printf("Mark the background with black and the object with white on the "
      "image. After doing so, press ENTER.");
    fgetc(stdin);

    if (readppm(new_filename, &width, &height, (pixel_t*)marked_image))
        return RETERR(1, "Cannot open input file.\n");

    /* TODO:
     * - convert this to a graph
     * - pass it to the CUDA kernel/CPU
     * - measure and print results
     */

    return 0;
}

