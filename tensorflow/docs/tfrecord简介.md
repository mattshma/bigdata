# tfrecord 简介
tfrecord 是TensoFlow 官方推荐的一种较为高效的数据读取方式。生成 tfrecord 格式的文件一般过程是先读取原生数据，然后转换为 tfrecord 格式，再存储到硬盘上。使用 tfrecord 文件时，把数据从相应的 tfrecord 文件中解码读取出来即可。

## tfrecord 格式简介
参考 [example.proto](https://github.com/tensorflow/tensorflow/blob/r1.3/tensorflow/core/example/example.proto) 和 [feature.proto](https://github.com/tensorflow/tensorflow/blob/r1.3/tensorflow/core/example/feature.proto)，代码如下：
```
// example.proto
message Example {
  Features features = 1;
};

message SequenceExample {
  Features context = 1;
  FeatureLists feature_lists = 2;
};

// feature.proto
message Feature {
  oneof kind {
    BytesList bytes_list = 1;
    FloatList float_list = 2;
    Int64List int64_list = 3;
  }
};

message Features {
  map<string, Feature> feature = 1;
};

message FeatureList {
  repeated Feature feature = 1;
};

message FeatureLists {
  map<string, FeatureList> feature_list = 1;
};
```
从注释中可以看出：Example 是 TensorFlow 中用于存储训练和预测数据的数据格式。Example 包含一个属性名称到属性值的键值对字典。其中属性名称是字段串，属性值可以为字符串（BytesList），实数列表（FloatList）和整数列表（Int64List）。如一个电影推荐应用中的一个 Example 结构如下：
```
features {
  feature {
    key: "age"
    value { float_list {
      value: 29.0
    }}
  }
  feature {
    key: "movie"
    value { bytes_list {
      value: "The Shawshank Redemption"
      value: "Fight Club"
    }}
  }
  feature {
    key: "movie_ratings"
    value { int64_list {
      value: 4
    }}
  }
}
```
SequenceExample 是表示一个或多个序列和 context 的 Example，即属性键是一个序列，这里主要分析 Example。SequenceExample 类似，不再分析。

## 生成 tfrecord 文件

当前目录下创建目录 `tfrecords`，进入 Python，招行如下命令：
```
import tensorflow as tf
import numpy as np

tfrecords_filename = 'tfrecords/train.tfrecord'
with tf.python_io.TFRecordWriter(tfrecords_filename) as writer:
    for i in range(10):
        img = np.random.randint(0, 255, size=(10, 10)).tostring()
        feature = {
            'lable': tf.train.Feature(int32_list = tf.train.Int64List(value=[i])),
            'img': tf.train.Feature(bytes_list = tf.train.BytesList(value=[img]))
        }
        example = tf.train.Example(features=tf.train.Features(feature=feature))
        writer.write(example.SerializeToString())
```

代码很简单，主要是构成 Example 这块。
ADD：官网关于生成 tfrecord 文件的[代码例子](https://github.com/tensorflow/tensorflow/blob/r1.3/tensorflow/examples/how_tos/reading_data/convert_to_records.py)。

## 读取 tfrecord 数据
如下：
```
def _parse_function(example_proto):
    features = {"image": tf.FixedLenFeature((), tf.string, default_value=""),
                "label": tf.FixedLenFeature((), tf.int64, default_value=0)}
    parsed_features = tf.parse_single_example(example_proto, features)
    return parsed_features["image"], parsed_features["label"]

filenames = ["tfrecords/train.tfrecord"]
dataset = tf.data.TFRecordDataset(filenames)
dataset = dataset.map(_parse_function)
```

参考[parse_single_example](https://www.tensorflow.org/api_docs/python/tf/parse_single_example)，其原型如下：
```
parse_single_example(
    serialized,
    features,
    name=None,
    example_names=None
)
```

serialized 为一个标量（scalar）的字符串 Tensor，即一个 Example。该类型可从 `tf.TFRecordReader` 的 `read` 方法得来；或遍历`tf.data.Dataset` 得到。



这里有个问题，使用 tfrecord 和直接从硬盘读取原生数据相比，到底有什么优势呢？
