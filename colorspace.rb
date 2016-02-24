#
# ruby-colorspace
#
# color space operating library
#
# NISHI Takao <zophos@koka-in.org>
#
# Time-stamp: <2016-02-24 16:59:17 zophos>
#
require 'narray'

module ColorSpace

    #
    # color profiles
    #
    module Profile
        #
        # for convenience
        # white points are defined on (Xn, Yn=1.0, Zn)
        # RGB points are defined on (xn, yn, zn; xn + yn + zn = 1.0)
        #

        #
        # White point of CIE standard illuminant (CIE 1931 $2^\circ$)
        #
        # https://en.wikipedia.org/wiki/Standard_illuminant#White_points_of_standard_illuminants
        #
        module WhitePoint
            C=[0.98071,1.0,1.18225].freeze
            D50=[0.9642,1.0,0.8249].freeze
            D65=[0.95046,1.0,1.08906].freeze
            E=[1.0,1.0,1.0].freeze
        end

        #
        # RGB color space
        #
        IDX_WHITE=0
        IDX_RED=1
        IDX_GREEN=2
        IDX_BLUE=3
        IDX_RGB=1..3

        CIE_RGB=[
            WhitePoint::E,
            [0.7347,0.2653,0.0],
            [0.2738,0.7174,0.0088],
            [0.1666,0.0089,0.8245]
        ].freeze

        SRGB=[
            WhitePoint::D65,
            [0.64,0.33,0.03],
            [0.30,0.60,0.10],
            [0.15,0.06,0.79]
        ].freeze

        AdobeRGB=[
            WhitePoint::D65
            [0.64,0.33,0.03],
            [0.21,0.71,0.08],
            [0.15,0.06,0.79]
        ].freeze

        NTSC_RGB=[
            WhitePoint::C,
            [0.67,0.33,0.00],
            [0.21,0.71,0.08],
            [0.14,0.08,0.78]
        ].freeze


        # for CIE L a* b* D50
        SRGB_D50=[
            WhitePoint::D50,
            [0.64844,0.33086,0.02070],
            [0.32117,0.59788,0.08095],
            [0.15590,0.06605,0.77805]
        ].freeze

        AdobeRGB_D50=[
            WhitePoint::D50,
            [0.64844,0.33086,0.02070],
            [0.23017,0.70157,0.06826],
            [0.15590,0.06605,0.77805]
        ].freeze

        Standard=SRGB

        #
        # helper functions
        #
        def white_point(profile)
            profile[IDX_WHITE]
        end

        def r_point(profile)
            profile[IDX_RED]
        end

        def g_point(profile)
            profile[IDX_GREEN]
        end

        def b_point(profile)
            profile[IDX_BLUE]
        end

        def rgb_point(profile)
            profile[IDX_RGB]
        end

        module_function :white_point,:r_point,:g_point,:b_point,:rgb_point
    end

    #
    # Linear RGB
    #
    # 0.0 <= (r,g,b) <= 1.0
    #
    class RGB
        def initialize(r,g,b)
            @r=r.to_f
            @g=g.to_f
            @b=b.to_f
        end
        attr_accessor :r,:g,:b

        def to_a
            [@r,@g,@b]
        end

        def to_gray
            @r*0.3+@g*0.59+@b*0.11
        end

        def to_srgb
            SRGB.transform(self)
        end

        def to_adobe_rgb
            AdobeRGB.transform(self)
        end

        def to_cmy
            CMY.transform(self)
        end

        def to_cmyk
            CMYK.transform(self)
        end

        def to_hsv
            HSV.transform(self)
        end

        def to_hls
            HLS.transform(self)
        end

        def to_yuv
            YUV.transform(self)
        end

        def to_xyz(profile=Profile::Standard)
            XYZ.transform(self,profile)
        end

        def to_cielab
            self.to_xyz(Profile::SRGB_D50).to_cielab(true)
        end
    end


    class SRGB<RGB
        def self.transform(rgb)
            _gamma=Proc.new{|c|
                c<=0.0031308 ? 12.92*c : 1.055*(c**(1.0/2.4))-0.055
            }

            rgb=rgb.to_rgb if rgb.respond_to?(:to_rgb)

            self.new(_gamma.call(rgb.r),
                     _gamma.call(rgb.g),
                     _gamma.call(rgb.b))
        end

        def to_rgb
            _degamma=Proc.new{|c|
                c<=0.040450 ? c/12.92 : ((c+0.055)/1.055)**2.4
            }

            RGB.new(_degamma.call(@r),
                    _degamma.call(@g),
                    _degamma.call(@b))
        end

        def to_xyz
            self.to_rgb.to_xyz(Profile::SRGB)
        end
    end

    class AdobeRGB<RGB
        def self.transform(rgb)
            _gamma=Proc.new{|c|
                c<=0.00174 ? 32.0*c : c**(1.0/2.2)
            }

            rgb=rgb.to_rgb if rgb.respond_to?(:to_rgb)

            self.new(_gamma.call(rgb.r),
                     _gamma.call(rgb.g),
                     _gamma.call(rgb.b))
        end

        def to_rgb
            _degamma=Proc.new{|c|
                c<=0.0556 ? c/32.0 : c**2.2
            }
            RGB.new(_degamma.call(@r),
                    _degamma.call(@g),
                    _degamma.call(@b))
        end

        def to_xyz
            self.to_rgb.to_xyz(Profile::AdobeRGB)
        end
    end

    class CMY
        def self.transform(obj)
            obj=obj.to_rgb unless obj.is_a?(RGB)

            (r,g,b)=obj.to_a
            self.new(1.0-r,1.0-g,1.0-b)
        end

        def initialize(c,m,y)
            @c=c.to_f
            @m=m.to_f
            @y=y.to_f
        end
        attr_accessor :c,:m,:y

        def to_a
            [@c,@m,@y]
        end

        def to_rgb
            RGB.new(1.0-@c,1.0-@m,1.0-@y)
        end
    end

    class CMYK
        def self.transform(obj)
            (c,m,y)=if(obj.is_a?(CMY))
                        obj.to_a
                    else
                        obj=obj.to_rgb unless obj.is_a?(RGB)
                        obj.to_cmy.to_a
                    end

            k=[c,m,y].min
            nk=1.0-k

            self.new((c-k)/nk,(m-k)/nk,(y-k)/nk,k)
        end

        def initialize(c,m,y,k)
            @c=c.to_f
            @m=m.to_f
            @y=y.to_f
            @k=k.to_f
        end
        attr_accessor :c,:m,:y,:k

        def to_a
            [@c,@m,@y,@k]
        end

        def to_cmy
            nk=1.0-@k

            CMY.new([1.0,@c*nk+@k].min,
                    [1.0,@m*nk+@k].min,
                    [1.0,@y*nk+@k].min)
        end

        def to_rgb
            self.to_cmy.to_rgb
        end
    end


    module Hue
        private

        DEG0=0.0
        DEG60=Math::PI/3.0
        DEG120=DEG60*2
        DEG240=DEG120*2
        DEG360=Math::PI*2.0

        def _order(rgb)
            (r,g,b)=rgb.to_a
            [[:r,r],[:g,g],[:b,b]].sort_by{|a| a[1] }
        end
        module_function :_order

        def _rgb2hue(order,max_min)
            r=order.assoc(:r)[1]
            g=order.assoc(:g)[1]
            b=order.assoc(:b)[1]

            case order[-1][0]
            when :r
                DEG60*(g-b)/max_min
            when :g
                DEG60*(b-r)/max_min+DEG120
            when :b
                DEG60*(r-g)/max_min+DEG240
            end
        end
        module_function :_rgb2hue

        def _hue_normalize
            while(true)
                if(@h<DEG0)
                    @h+=DEG360
                elsif(@h>=DEG360)
                    @h-=DEG360
                else
                    break
                end
            end
        end

        def _hue2rgb(min,max)
            max_min=max-min

            case (@h/DEG60).to_i
            when 0
                [max,@h/DEG60*max_min+min,min]
            when 1
                [(DEG120-@h)/DEG60*max_min+min,max,min]
            when 2
                [min,max,(@h-DEG120)/DEG60*max_min+min]
            when 3
                [min,(DEG240-@h)/DEG60*max_min+min,max]
            when 4
                [(@h-DEG240)/DEG60*max_min+min,min,max]
            when 5
                [max,min,(DEG360-@h)/DEG60*max_min+min]
            end
        end
    end

    class HSV
        include Hue

        def self.transform(obj)
            obj=obj.to_rgb unless obj.is_a?(RGB)

            order=Hue::_order(obj)
            v=order[-1][1]

            max_min=v-order[0][1]

            s=max_min/v

            h=Hue::_rgb2hue(order,max_min)

            self.new(h,s,v)
        end

        def initialize(h,s,v)
            @h=h.to_f
            @s=s.to_f
            @v=v.to_f

            _hue_normalize
        end

        def to_a
            [@h,@s,@v]
        end

        def to_rgb
            max=@v
            min=(1.0-@s)*@v

            RGB.new(*_hue2rgb(min,max))
        end
    end

    #
    # bicone model HLS
    #
    class HLS
        include Hue

        def self.transform(obj)
            obj=obj.to_rgb unless obj.is_a?(RGB)

            order=Hue::_order(obj)
            max_min=order[-1][1]-order[0][1]

            h=if(max_min==0.0)
                  0.0
              else
                  Hue::_rgb2hue(order,max_min)
              end

            l2=(order[-1][1]+order[0][1])

            s=if(max_min==0.0)
                  0.0
              elsif(l2<1.0)
                  max_min/l2
              else
                  max_min/(2.0-l2)
              end

            self.new(h,l2/2,s)
        end

        def initialize(h,l,s)
            @h=h.to_f
            @l=l.to_f
            @s=s.to_f

            _hue_normalize
        end
        attr_accessor :h,:l,:s

        def to_a
            [@h,@l,@s]
        end

        def to_rgb
            return RGB.new(@l,@l,@l) if @s==0.0

            ls=@l*@s
            (min,max)=if(@l<0.5)
                          [@l-ls,@l+ls]
                      else
                          [@l-@s+ls,@l+@s-ls]
                      end

            RGB.new(*_hue2rgb(min,max))
        end
    end

    class YUV
        CENTER=0.5

        def self.transform(obj)
            obj=obj.to_rgb unless obj.is_a?(RGB)

            (r,g,b)=obj.to_a

            self.new(0.299*r+0.587*g+0.114*b,
                     -0.147*r-0.289*g+0.437*b+CENTER,
                     0.615*r-0.515*g-0.100*b+CENTER)
        end

        def initialize(y,u,v)
            @y=y
            @u=u
            @v=v
        end
        attr_accessor :y,:u,:v

        def to_a
            [@y,@u,@v]
        end

        def to_rgb
            RGB.new(@y+0.000*(@u-CENTER)+1.140*(@v-CENTER),
                    @y-0.394*(@u-CENTER)-0.581*(@v-CENTER),
                    @y+2.028*(@u-CENTER)+0.000*(@v-CENTER))
        end
    end

    #
    # CIE XYZ
    #
    # http://w3.kcua.ac.jp/~fujiwara/infosci/colorspace/colorspace1.html
    #
    class XYZ
        #
        # RGB -> XYZ transform matrix
        #
        # http://w3.kcua.ac.jp/~fujiwara/infosci/colorspace/rgb_xyz.html
        #
        def self.matrix(profile)
            v=NVector.to_na(profile[0])
            m=NMatrix.dfloat(3,3)
            3.times{|i|
                m[i,true]=profile[i+1]
            }

            t=v/m

            tm=NMatrix.dfloat(3,3)
            3.times{|i|
                tm[i,i]=t[i]
            }

            m*tm
        end

        #
        # RGB -> XYZ matrix to profile array [white, red, green, blue]
        #
        def self.decomp(matrix)
            t=matrix.sum(1)
            tm=NMatrix.dfloat(3,3)
            3.times{|i|
                tm[i,i]=t[i]
            }
            rgbp=matrix*(tm.inverse)

            [(rgbp*(t.transpose)).to_a.flatten,
                rgbp.transpose.to_a]
        end

        #
        # white point convert matrix
        #
        # http://w3.kcua.ac.jp/~fujiwara/infosci/colorspace/bradford.html
        #
        Braford_M=
            NMatrix.to_na([[0.8951000,0.2664000,-0.1614000],
                              [-0.7502000,1.7135000,0.0367000],
                              [0.0389000,-0.0685000,1.0296000]])
        Braford_M_inv=Braford_M.inverse

        def self.bradford_transform_matrix(s_wp,d_wp)
            s=NMatrix.dfloat(1,3)
            s[0,true]=s_wp

            d=NMatrix.dfloat(1,3)
            d[0,true]=d_wp

            s_lms=Braford_M*s
            d_lms=Braford_M*d

            d_lms.div!(s_lms)

            m=NMatrix.dfloat(3,3)
            3.times{|i|
                m[i,i]=d_lms[0,i]
            }

            (Braford_M_inv*m)*Braford_M
        end

        def self.transform(obj,profile=Profile::Standard)
            obj=obj.to_rgb unless obj.is_a?(RGB)

            m=self.matrix(profile)
            coord=(m*NVector.to_na(obj.to_a)).to_a

            xyz=self.new(*(coord+[profile[0]]))
        end


        def initialize(x,y,z,white_point)
            @x=x
            @y=y
            @z=z
            @white_point=white_point
        end
        attr_accessor :x,:y,:z
        attr_reader :white_point

        def to_a
            [@x,@y,@z]
        end

        def to_rgb(profile=Profile::Standard)
            d_wp=profile[0]

            unless(@white_point==d_wp)
                #
                # compare by numeric for each element.
                #
                3.times{|i|
                    #
                    # when found out difference of value,
                    # do Bradford transformation
                    #
                    return self.
                    bradford_transform(d_wp).
                    to_rgb(profile) unless @white_point[i]==d_wp[i]
                }
            end

            self.to_rgb_with_matrix(self.class.matrix(profile))
        end

        def to_rgb_with_matrix(matrix)
            RGB.new(*((NVector.to_na(self.to_a)/matrix).to_a))
        end

        def white_point=(d_wp)
            m=self.class.bradford_transform_matrix(@white_point,
                                                   d_wp)
            (@x,@y,@z)=(m*NVector.to_na(self.to_a)).to_a
            @white_point=d_wp
        end
        def bradford_transform(d_wp)
            obj=self.class.new(@x,@y,@z,@white_point)
            obj.white_point=d_wp
            obj
        end

        def to_cielab(with_current_white_point=false)
            if(with_current_white_point)
                CIELab.transform(self)
            else
               self.bradford_transform(Profile::WhitePoint::D50).to_cielab(true)
            end
        end
    end

    #
    # CIE L a* b*
    #
    class CIELab
        GAMMA=6.0/29.0
        QB_GAMMA=GAMMA*GAMMA*GAMMA

        GAMMA_L=29.0/3.0
        QB_GAMMA_L=GAMMA_L*GAMMA_L*GAMMA_L

        def self.transform(obj)
            unless(obj.respond_to?(:white_point))
                obj=obj.to_rgb unless obj.is_a?(RGB)
                obj=obj.to_xyz
            end

            _gamma=Proc.new{|t|
                t>QB_GAMMA ? 116.0*t**(1.0/3.0)-16.0 : QB_GAMMA_L*t
            }

            (x,y,z)=obj.to_a
            (xn,yn,zn)=obj.white_point

            l=_gamma.call(y/yn)
            self.new(l,
                     500.0/116.0*(_gamma.call(x/xn)-l),
                     200.0/116.0*(l-_gamma.call(z/zn)),
                     [xn,yn,zn])
        end

        def initialize(l,a,b,white_point)
            @l=l
            @a=a
            @b=b
            @white_point=white_point
        end
        attr_reader :l,:a,:b

        def to_a
            [@l,@a,@b]
        end

        def to_xyz
            fy=(@l+16.0)/116.0
            fx=fy+(@a/500.0)
            fz=fy-(@b/200.0)

            (xn,yn,zn)=@white_point

            _degamma=Proc.new{|c,n|
                c>GAMMA ? c*c*c*n : (116.0*c-16.0)*n/QB_GAMMA_L
            }

            XYZ.new(_degamma.call(fx,xn),
                    _degamma.call(fy,yn),
                    _degamma.call(fz,zn),
                    @white_point)
        end

        #
        # convert to sRGB (D65)
        #
        def to_rgb
            self.to_xyz.to_rgb(Profile::SRGB_D50)
        end
    end
end
