#ifndef __CPU_UTILS_H__
#define __CPU_UTILS_H__

struct pixel_t {
    unsigned char r, g, b;
};

extern const pixel_t WHITE;
extern const pixel_t BLACK;

/* Delete white and black colours from the image */
void normalize_image(unsigned width, unsigned height, pixel_t *image);

inline bool color_eq(const pixel_t &p, unsigned char r, unsigned char g, unsigned char b)
{ return p.r == r && p.g == g && p.b == b; }

inline bool operator==(const pixel_t &a, const pixel_t &b)
{ return a.r == b.r && a.g == b.g && a.b == b.b; }

// TODO: check height and width 
int writeppm(const char *filename, unsigned width, unsigned height,
  const pixel_t pixels[]);
int readppm(const char *filename, unsigned *width, unsigned *height,
  pixel_t pixels[]);

int RETERR(int code, const char *err_message, ...);

#endif
