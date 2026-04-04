defmodule Exiffer.Fixtures.JPEG do
  alias Exiffer.JPEG

  def no_exif() do
    %JPEG{
      headers: [
        %Exiffer.JPEG.Header.JFIF{
          version: <<1, 1>>,
          resolution_units: 0,
          x_resolution: 1,
          y_resolution: 1,
          thumbnail_width: 0,
          thumbnail_height: 0,
          thumbnail: ""
        }
      ]
    }
  end

  def minimal_exif() do
    %JPEG{
      headers: [
        %Exiffer.JPEG.Header.JFIF{
          version: <<1, 1>>,
          resolution_units: 0,
          x_resolution: 1,
          y_resolution: 1,
          thumbnail_width: 0,
          thumbnail_height: 0,
          thumbnail: ""
        },
        %Exiffer.JPEG.Header.APP1.EXIF{
          byte_order: :little,
          ifd_block: %Exiffer.JPEG.IFDBlock{
            ifds: [
              %Exiffer.JPEG.IFD{
                entries: [
                  %Exiffer.JPEG.Entry{
                    type: :image_width,
                    format: :int16u,
                    label: "Image Width",
                    magic: <<1, 0>>,
                    value: 3286
                  },
                  %Exiffer.JPEG.Entry{
                    type: :image_height,
                    format: :int16u,
                    label: "Image Height",
                    magic: <<1, 1>>,
                    value: 2432
                  }
                ]
              }
            ]
          }
        }
      ]
    }
  end

  def with_exif_sub_ifd() do
    %JPEG{
      headers: [
        %Exiffer.JPEG.Header.JFIF{
          version: <<1, 1>>,
          resolution_units: 0,
          x_resolution: 1,
          y_resolution: 1,
          thumbnail_width: 0,
          thumbnail_height: 0,
          thumbnail: ""
        },
        %Exiffer.JPEG.Header.APP1.EXIF{
          byte_order: :little,
          ifd_block: %Exiffer.JPEG.IFDBlock{
            ifds: [
              %Exiffer.JPEG.IFD{
                entries: [
                  %Exiffer.JPEG.Entry{
                    type: :image_width,
                    format: :int16u,
                    label: "Image Width",
                    magic: <<1, 0>>,
                    value: 3286
                  },
                  %Exiffer.JPEG.Entry{
                    type: :image_height,
                    format: :int16u,
                    label: "Image Height",
                    magic: <<1, 1>>,
                    value: 2432
                  },
                  %Exiffer.JPEG.Entry{
                    type: :exif_offset,
                    format: :int32u,
                    label: "Exif Offset",
                    magic: <<135, 105>>,
                    value: %Exiffer.JPEG.IFD{
                      entries: [
                        %Exiffer.JPEG.Entry{
                          type: :exposure_time,
                          format: :rational_64u,
                          label: "Exposure Time",
                          magic: <<130, 154>>,
                          value: {99998, 1_000_000}
                        },
                        %Exiffer.JPEG.Entry{
                          type: :f_number,
                          format: :rational_64u,
                          label: "F Number",
                          magic: <<130, 157>>,
                          value: {240, 100}
                        }
                      ]
                    }
                  }
                ]
              }
            ]
          }
        }
      ]
    }
  end

  def with_gps() do
    %JPEG{
      headers: [
        %Exiffer.JPEG.Header.JFIF{
          version: <<1, 1>>,
          resolution_units: 0,
          x_resolution: 1,
          y_resolution: 1,
          thumbnail_width: 0,
          thumbnail_height: 0,
          thumbnail: ""
        },
        %Exiffer.JPEG.Header.APP1.EXIF{
          byte_order: :little,
          ifd_block: %Exiffer.JPEG.IFDBlock{
            ifds: [
              %Exiffer.JPEG.IFD{
                entries: [
                  %Exiffer.JPEG.Entry{
                    type: :gps_info,
                    format: :int32u,
                    label: "GPSInfo",
                    magic: <<0x88, 0x25>>,
                    value: %Exiffer.JPEG.IFD{
                      entries: [
                        %Exiffer.JPEG.Entry{
                          type: :gps_latitude_ref,
                          format: :string,
                          label: "GPS Latitude Ref",
                          magic: <<0x00, 0x01>>,
                          value: "N"
                        },
                        %Exiffer.JPEG.Entry{
                          type: :gps_latitude,
                          format: :rational_64u,
                          label: "GPS Latitude",
                          magic: <<0x00, 0x02>>,
                          value: [{51, 1}, {30, 1}, {0, 1}]
                        }
                      ]
                    }
                  }
                ]
              }
            ]
          }
        }
      ]
    }
  end

  def with_sof0() do
    %JPEG{
      headers: [
        %Exiffer.JPEG.Header.SOF0{
          bits_per_sample: 8,
          width: 640,
          height: 480,
          color_components_count: 3,
          components: [],
          encoding_process: nil,
          y_cb_cr_sub_sampling: nil
        }
      ]
    }
  end

  def with_exif_dimensions() do
    %JPEG{
      headers: [
        %Exiffer.JPEG.Header.APP1.EXIF{
          byte_order: :little,
          ifd_block: %Exiffer.JPEG.IFDBlock{
            ifds: [
              %Exiffer.JPEG.IFD{
                entries: [
                  %Exiffer.JPEG.Entry{
                    type: :exif_image_width,
                    format: :int16u,
                    label: "Exif Image Width",
                    magic: <<0xA0, 0x02>>,
                    value: 1920
                  },
                  %Exiffer.JPEG.Entry{
                    type: :exif_image_height,
                    format: :int16u,
                    label: "Exif Image Height",
                    magic: <<0xA0, 0x03>>,
                    value: 1080
                  }
                ]
              }
            ]
          }
        }
      ]
    }
  end
end
