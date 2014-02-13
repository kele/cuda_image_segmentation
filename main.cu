#include <cstdio>
#include <cstring>

#include "cpu_utils.hpp"
#include "cpu_seg.hpp"

#define MAX_HEIGHT 1024
#define MAX_WIDTH  1024

pixel_t image[MAX_HEIGHT][MAX_WIDTH];
pixel_t marked_image[MAX_HEIGHT][MAX_WIDTH];
pixel_t segmented_image[MAX_HEIGHT][MAX_WIDTH];

void segmentation_gpu(int width, int height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image);

int main(int argc, char *argv[])
{
    if (argc != 3)
        return RETERR(-1,
          "Usage: [n | g | c] flow image.ppm\n"
          "\tn - normalize the image (output is written to _image.ppm\n"
          "\tg - use GPU (CUDA)\n"
          "\tc - use CPU\n"
          "The result image is written to Simage.ppm\n\n");

    const bool should_normalize = argv[1][0] == 'n';
    const bool use_cpu = argv[1][0] == 'c';
    const bool use_gpu = argv[1][0] == 'g';

    const char *filename = argv[2];
    char new_filename[strlen(filename) + 1];
    strcpy(&new_filename[1], filename);
    new_filename[0] = '_';

    unsigned width, height;

    if (readppm(filename, &width, &height, (pixel_t *)image))
        return RETERR(-2, "Cannot open input file.\n");

    if (should_normalize) {
        normalize_image(width, height, (pixel_t *)image);
        if (writeppm(new_filename, width, height, (pixel_t *)image))
            return RETERR(-3, "Cannot write to %s\n", new_filename);
        
        return 0;
    }

    if (readppm(new_filename, &width, &height, (pixel_t *)marked_image))
        return RETERR(-2, "Cannot open input file.\n");

    if (use_gpu) {
        if ((width % 32) || (height % 32))
            return RETERR(-4, "Width and height have to be a multiplication of 32.\n"); 
        segmentation_gpu(width, height, (pixel_t *)image, (pixel_t *)marked_image,
          (pixel_t *)segmented_image);
    }
    else if (use_cpu)
        segmentation_cpu(width, height, (pixel_t *)image, (pixel_t *)marked_image,
          (pixel_t *)segmented_image);

    new_filename[0] = 'S';
    if (writeppm(new_filename, width, height, (pixel_t *)segmented_image))
        return RETERR(1, "Cannot write to %s\n", new_filename);

    return 0;
}

