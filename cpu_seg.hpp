#ifndef __CPU_SEG_H__
#define __CPU_SEG_H__

#include <cstring>
#include <vector>

#include "cpu_utils.hpp"


const int MULT = 100000;
const float LAMBDA = 0.000001f;
#define INF 0x1ffffffe

inline bool in_range(int x, int a, int b) { return a <= x && x <= b; }

// TODO: this should be somehow determined experimentally
const int VARIANT = 255.f;

inline int compute_edge(const pixel_t &a, const pixel_t &b)
{
    float x = (float)a.r - b.r;
    float y = (float)a.g - b.g;
    float z = (float)a.b - b.b;
    float r = exp(-(x*x + y*y + z*z)/VARIANT); // DEBUG: there was sqrt there
    return MULT*r;
}

class ImageGraph {
public:
    static const int REG_NEIGHBOURS = 4;
    static const int NEIGHBOURS = REG_NEIGHBOURS + 2;
    static const int SOURCE = NEIGHBOURS - 2;
    static const int SINK = NEIGHBOURS - 1;

    struct node_t {
        std::vector<int> c;
        int height;
        int overflow;
        int neighbours;

        node_t(int neighbours)
            : neighbours(neighbours), c(neighbours), overflow(0), height(0) {}
    };

    struct regular_node_t : public node_t
    {
        regular_node_t()
            : node_t(NEIGHBOURS) {}
    };

    std::vector<regular_node_t> nodes;
    node_t source;
    node_t sink;
    int width, height;

    ImageGraph(int width, int height)
        : width(width),
          height(height),
          nodes(width*height),
          source(width*height),
          sink(width*height)
    {}

    inline regular_node_t &get(int x, int y) { return nodes[y*width + x]; }
};

#define DIV 26
class Histogram {
public:
    enum { OBJ, BG };

    Histogram(int width, int height, const pixel_t *image, const pixel_t *marks)
    {
        memset(count, 0, 10*10*10*sizeof(int));
        total_count = width*height;

        for (int i = 0; i < width*height; i++) {
            if (marks[i] == WHITE)
                count[image[i].r/DIV][image[i].g/DIV][image[i].b/DIV]++;
        }
    }

    inline float prob_obj(const pixel_t &pix) const
    {
        float c = count[pix.r/DIV][pix.g/DIV][pix.b/DIV];
        if (c == 0)
            c = 0.0001f;
        return c/total_count;
    }
    inline float prob_bg(const pixel_t &pix) const
    {
        return 1.f - prob_obj(pix);
    }

private:
    int count[10][10][10];
    int total_count;

};

void segmentation_cpu(int width, int height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image);

#endif
