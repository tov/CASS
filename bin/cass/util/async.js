const par_map = (f, xs) => Promise.all(xs.map(f))

const seq_map = async (f, xs) => {
  const result = []

  for (const x of xs)
    result.push(await f(x))

  return result
}

const par_foreach = (xs, f) => par_map(f, xs)
const seq_foreach = (xs, f) => seq_map(f, xs)

module.exports = {
  par_foreach, par_map,
  seq_foreach, seq_map,
}
