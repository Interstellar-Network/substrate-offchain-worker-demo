use frame_support::pallet_prelude::*;
// use frame_support::BoundedVec;
mod bounded_vec;
use bounded_vec::BoundedVec;

////////////////////////////////////////////////////////////////////////////////
/// TEMP
/// until we use https://github.com/paritytech/substrate/pull/11314
///

#[cfg(feature = "std")]
use serde::{
    de::{Error, SeqAccess, Visitor},
    Deserialize, Deserializer, Serialize,
};

pub type MyBoundedVec<T, S> = BoundedVec<T, S>;

#[cfg(feature = "std")]
impl<'de, T, S: Get<u32>> Deserialize<'de> for MyBoundedVec<T, S>
where
    T: Deserialize<'de>,
{
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        struct VecVisitor<T, S: Get<u32>>(PhantomData<(T, S)>);

        impl<'de, T, S: Get<u32>> Visitor<'de> for VecVisitor<T, S>
        where
            T: Deserialize<'de>,
        {
            type Value = Vec<T>;

            fn expecting(&self, formatter: &mut std::fmt::Formatter) -> std::fmt::Result {
                formatter.write_str("a sequence")
            }

            fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
            where
                A: SeqAccess<'de>,
            {
                let size = seq.size_hint().unwrap_or(0);
                let max = match usize::try_from(S::get()) {
                    Ok(n) => n,
                    Err(_) => return Err(A::Error::custom("can't convert to usize")),
                };
                if size > max {
                    Err(A::Error::custom("out of bounds"))
                } else {
                    let mut values = Vec::with_capacity(size);

                    while let Some(value) = seq.next_element()? {
                        values.push(value);
                        if values.len() > max {
                            return Err(A::Error::custom("out of bounds"));
                        }
                    }

                    Ok(values)
                }
            }
        }

        let visitor: VecVisitor<T, S> = VecVisitor(PhantomData);
        deserializer.deserialize_seq(visitor).map(|v| {
            MyBoundedVec::<T, S>::try_from(v).map_err(|_| Error::custom("out of bounds"))
        })?
    }
}
