const par = Promise.all.bind(Promise)

const seq = async xs => {
  const result = []

  for (const x of xs)
    result.push(await x)

  return result
}

const par_map = (f, xs) => par(xs.map(f))
const seq_map = (f, xs) => seq(xs.map(f))

const par_foreach = (xs, f) => par_map(f, xs)
const seq_foreach = (xs, f) => seq_map(f, xs)

module.exports = {
  par, par_foreach, par_map,
  seq, seq_foreach, seq_map,
}
