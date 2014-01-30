#include <cstdio>
#include <cstring>
#include <cstdarg>

#include "cpu_utils.hpp"

const pixel_t OBJECT = { .r = 255, .g = 255, .b = 255 };
const pixel_t BACKGR = { .r = 0, .g = 0, .b = 0 };


int writeppm(const char *filename, unsigned width, unsigned height,
  const pixel_t pixels[])
{
    FILE *f = fopen(filename, "w");
    if (f == NULL)
        return 1;

    fprintf(f, "P6\n%u\n%u\n255\n", width, height);
    for (unsigned y = 0; y < height; y++)
        for (unsigned x = 0; x < width; x++) {
            fputc(pixels[y*width + x].r, f);
            fputc(pixels[y*width + x].g, f);
            fputc(pixels[y*width + x].b, f);
        }
    fclose(f);
    return 0;
}

int readppm(const char *filename, unsigned *width, unsigned *height,
  pixel_t pixels[])
{
    FILE *f = fopen(filename, "r");
    if (f == NULL)
        return 1;

    int ret = 0;

    char magic[3];
    if (fscanf(f, "%2s", magic) != 1 || strcmp(magic, "P6") != 0) {
        ret = 1;
        goto out;
    }
    fscanf(f, "%u%u%*u", width, height);
    fgetc(f); // last whitespace character of the header

    for (unsigned y = 0; y < *height; y++) {
        for (unsigned x = 0; x < *width; x++) {
            pixels[y*(*width) + x].r = fgetc(f);
            pixels[y*(*width) + x].g = fgetc(f);
            pixels[y*(*width) + x].b = fgetc(f);
        }
    }

out:
    fclose(f);
    return ret;
}

void normalize_image(unsigned width, unsigned height, pixel_t *image)
{
    for (unsigned y = 0; y < height; y++)
        for (unsigned x = 0; x < width; x++)
            if (color_eq(image[y*height + x], 255, 255, 255))
                image[y*height + x].b = 254;
            else if (color_eq(image[y*height + x], 0, 0, 0))
                image[y*height + x].b = 1;
}

int RETERR(int code, const char *err_message, ...)
{
    va_list args;
    va_start(args, err_message);
    vfprintf(stderr, err_message, args);
    va_end(args);
    return code;
}
