#ifndef __UTILITIES_H__
#define __UTILITIES_H__

#define MAX_HEIGHT 100000
#define MAX_WIDTH  100000

struct pixel_t {
    unsigned char r, g, b;
    unsigned char reserved;
};

extern const pixel_t OBJECT;
extern const pixel_t BACKGR;


inline int myabs(int a, int b)
{ return (a > b) ? (a - b) : (b - a); }

inline int color_eq(pixel_t p, unsigned char r, unsigned char g, unsigned char b)
{ return p.r == r && p.g == g && p.b == b; }

inline int colordiff(pixel_t a, pixel_t b)
{ return myabs(a.r, b.r) + myabs(a.g, b.g) + myabs(a.b, b.b); }

/* Also checks if width < MAX_WIDTH and height < MAX_HEIGHT */
int writeppm(const char *filename, unsigned width, unsigned height,
  const pixel_t pixels[]);
int readppm(const char *filename, unsigned *width, unsigned *height,
  pixel_t pixels[]);

int RETERR(int code, const char *err_message, ...);

#endif
