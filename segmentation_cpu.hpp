#ifndef __SEGMENTATION_CPU_H__
#define __SEGMENTATION_CPU_H__

#include "utilities.hpp"

void segmentation_cpu(unsigned width, unsigned height, const pixel_t *image,
  const pixel_t *marks, pixel_t *segmented_image);

#endif
