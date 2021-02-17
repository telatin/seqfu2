import neo

let
  v1 = makeVector(5, proc(i: int): float32 = (i * i).float32)
  v2 = randomVector(7, max = 3'f32) # max is no longer optional, to distinguish 32/64 bit
  v3 = constantVector(5, 3.5'f32)
  v4 = zeros(8, float32)
  v5 = ones(9, float32)
  v6 = vector(1'f32, 2'f32, 3'f32, 4'f32, 5'f32)
  v7 = vector([1.2'f32, 3.4'f32, 5.6'f32])
  m1 = makeMatrix(6, 3, proc(i, j: int): float32 = (i + j).float32)
  m2 = randomMatrix(2, 8, max = 1.6'f32)
  m3 = constantMatrix(3, 5, 1.8'f32, order = rowMajor) # order is optional, default colMajor
  m4 = ones(3, 6, float32)
  m5 = zeros(5, 2, float32)
  m6 = eye(7, float32)

let
  table = matrix(@[
    @[1.2'f32, 3.5'f32, 4.3'f32],
    @[1.1'f32, 4.2'f32, 1.7'f32],
    @[4.21'f32, 43.2'f32, 2.7'f32],
    @[8.21'f32, 31.2'f32, 24.7'f32]

  ])




echo "Shape: ", table.dim().rows, " x ", table.dim().columns
echo table

echo table.column(0)
echo table.column(0).sum()
echo "table[0]: ",type(table.column(0))

for c in table.columns():
  echo c.sum(), "\t>\t", c / c.sum()


