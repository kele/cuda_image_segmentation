#include <cstdio>
#include <cstring>

#include "cpu_utils.hpp"
#include "cpu_seg.hpp"

#define MAX_HEIGHT 1000
#define MAX_WIDTH  1000

pixel_t image[MAX_HEIGHT][MAX_WIDTH];
pixel_t marked_image[MAX_HEIGHT][MAX_WIDTH];
pixel_t segmented_image[MAX_HEIGHT][MAX_WIDTH];


int main(int argc, char *argv[])
{
    if (argc != 3)
        return RETERR(1, "Usage: [1 | 0] flow image.ppm\n1 if the marking is not present");

    const bool should_normalize = argv[1][0] == '1';

    const char *filename = argv[2];
    char new_filename[strlen(filename) + 1];
    strcpy(&new_filename[1], filename);
    new_filename[0] = '_';

    unsigned width, height;

    if (readppm(filename, &width, &height, (pixel_t *)image))
        return RETERR(1, "Cannot open input file.\n");

    if (should_normalize) {
        normalize_image(width, height, (pixel_t *)image);
        if (writeppm(new_filename, width, height, (pixel_t *)image))
            return RETERR(1, "Cannot write to %s\n", new_filename);

        printf("Mark the background with black and the object with white on the "
          "image. After doing so, press ENTER.");
        fgetc(stdin);
    }

    if (readppm(new_filename, &width, &height, (pixel_t *)marked_image))
        return RETERR(1, "Cannot open input file.\n");

    segmentation_cpu(width, height, (pixel_t *)image, (pixel_t *)marked_image, (pixel_t *)segmented_image);

    new_filename[0] = 'S';
    if (writeppm(new_filename, width, height, (pixel_t *)segmented_image))
        return RETERR(1, "Cannot write to %s\n", new_filename);


    return 0;
}

