#include <cstdlib>
#include <cmath>

#include "cpu_seg.h"

#define LAMBDA 1.0f

inline bool in_range(int x, int a, int b) { return a <= x && x <= b; }

void segmentation_cpu(unsigned width, unsigned height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image)
{
    Graph g(width, height, image);
    Histogram hist(width, height, image, marks);

    const int delt[8][2] = {
      {-1, -1}, {-1,  0}, {-1, +1},
      { 0, -1},           { 0, +1},
      {+1, -1}, {+1,  0}, {+1, +1}};

    /* neighbour edges */
    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            node_t &v = g.get(x, y);
            
            /* neighbours */
            for (unsigned i = 0; i < 8; i++) {
                if (in_range(y + delt[i][0], 0, height - 1) &&
                  in_range(x + delt[i][1], 0, width - 1)) {
                    unsigned dy = y + delt[i][0];
                    unsigned dx = x + delt[i][1];
                    node_t &u = g.get(dx, dy);

                    v.c[i] = colordiff(v.color, u.color);
                }
            }
        }
    }

    /* source, sink edges */
    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            node_t &v = g.get(x, y);

            float k = 0;
            for (unsigned i = 0; i < 8; i++)
                k = (k < c_neigh(v, i)) ? c_neigh(v, i) : k;
            k = k + 1;

            if (colordiff(marks[y*height + x], OBJECT) == 0) {
                c_source(v) = c_source_rev(v) = k;
                c_sink(v) = c_sink_rev(v) = 0;
            } else if (colordiff(marks[y*height + x], BACKGR) == 0) {
                c_sink(v) = c_sink_rev(v) = k;
                c_source(v) = c_source_rev(v) = 0;
            } else {
                c_source(v) = LAMBDA*(-log(hist.get_probability(Histogram::BG, v.color)));
                c_source_rev(v) = c_source(v);
                c_sink(v) = LAMBDA*(-log(hist.get_probability(Histogram::OBJ, v.color)));
                c_sink_rev(v) = c_sink(v);
            }
        }
    }

    /* initialise preflow */
    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            node_t &v = g.get(x, y);
            if (c_source(v) > 0) {
                f_sink_rev(v) = c_sink_rev(v);
                v.overflow = c_sink_rev(v);
            }
        }
    }

    // TODO: push relabel
}
