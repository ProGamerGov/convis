require 'torch'
require 'nn'
require 'image'
require 'loadcaffe' 

function preprocess(img)
   local mean_pixel = torch.DoubleTensor({103.939, 116.779, 123.68})
   local perm = torch.LongTensor{3, 2, 1}
   img = img:index(1, perm):mul(256.0)
   mean_pixel = mean_pixel:view(3, 1, 1):expandAs(img)
   img:add(-1, mean_pixel)
   return img
end

function deprocess(img)
  local mean_pixel = torch.DoubleTensor({103.939, 116.779, 123.68})
  mean_pixel = mean_pixel:view(3, 1, 1):expandAs(img)
  img = img + mean_pixel
  local perm = torch.LongTensor{3, 2, 1}
  img = img:index(1, perm):div(256.0)
  return img
end

local cmd = torch.CmdLine()

cmd:option('-image', 'examples/inputs/tubingen.jpg')
cmd:option('-output_dir', 'convis', 'directory where to place images')

cmd:option('-proto', 'models/VGG_ILSVRC_19_layers_deploy.prototxt')
cmd:option('-model', 'models/VGG_ILSVRC_19_layers.caffemodel')
cmd:option('-layer', 'relu4_2', 'layer for examine')

local params = cmd:parse(arg)

local content_image = image.load(params.image, 3)
local content_image_caffe = preprocess(content_image):float()
local img = content_image_caffe:clone():float()


local cnn = loadcaffe.load(params.proto, params.model, "nn"):float()

local net = nn.Sequential()


for i = 1, #cnn do
      local layer = cnn:get(i)
      local typ = torch.type(layer)
      local name = layer.name
      print(name, typ)
      net:add(layer)
      if (name == params.layer) then break end
end

local y = net:forward(img)

local n = y:size(1)

local ofn = params.output_dir .. "/" .. string.sub(params.image:match("[^/]+$"), 1, -5) .. "-" .. params.layer 

for i = 1, n do
  local y13 = y:clone():narrow(1,i,3)
  y13[2] = y13[1]
  y13[3] = y13[1]
  local disp = deprocess(y13:double())
  disp = image.minmax{tensor=disp, min=0, max=1}
  disp = image.scale(disp, content_image:size(3), content_image:size(2))
  local r = torch.cmul(disp:double(), content_image:double())
  local filename = ofn .. "-" .. i..".png"
  image.save(filename, r)
  print("saving image ",filename)
end 

