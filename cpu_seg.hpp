#ifndef __CPU_SEG_H__
#define __CPU_SEG_H__

#include <cstring>
#include <vector>

#include "cpu_utils.hpp"

class ImageGraph {
public:
    static const unsigned REG_NEIGHBOURS = 4;
    static const unsigned NEIGHBOURS = REG_NEIGHBOURS + 2;
    static const unsigned SOURCE = REG_NEIGHBOURS - 2;
    static const unsigned SINK = REG_NEIGHBOURS - 1;

    struct node_t {
        std::vector<float> c;
        int height;
        float overflow;
        unsigned neighbours;

        node_t(unsigned neighbours)
            : neighbours(neighbours), c(neighbours) {}
    };

    struct regular_node_t : public node_t
    {
        regular_node_t()
            : node_t(NEIGHBOURS) {}
    };

    std::vector<regular_node_t> nodes;
    node_t source;
    node_t sink;
    unsigned width, height;

    ImageGraph(unsigned width, unsigned height)
        : nodes(width*height),
          source(width*height),
          sink(width*height)
    {}

    inline regular_node_t &get(unsigned x, unsigned y) { return nodes[y*height + x]; }
};

#define DIV 26
class Histogram {
public:
    enum { OBJ, BG };

    Histogram(unsigned width, unsigned height, const pixel_t *image, const pixel_t *marks)
    {
        memset(count, 0, 2*10*10*10*sizeof(*count));
        total_count = width*height;

        for (unsigned i = 0; i < width*height; i++) {
            if (color_eq(marks[i], OBJECT))
                count[OBJ][image[i].r/DIV][image[i].g/DIV][image[i].b/DIV];
            else if (colordiff(marks[i], BACKGR) == 0)
                count[BG][image[i].r/DIV][image[i].g/DIV][image[i].b/DIV];
        }
    }

    inline float prob_obj(const pixel_t &pix) const
    { return probability(OBJ, pix); }
    inline float prob_bg(const pixel_t &pix) const
    { return probability(BG, pix); }
    inline float probability(int lab, const pixel_t &pix) const
    {
        return (float)count[lab][pix.r/DIV][pix.g/DIV][pix.b/DIV]/total_count;
    }

private:
    unsigned count[2][10][10][10];
    unsigned total_count;

};

void segmentation_cpu(unsigned width, unsigned height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image);

#endif
