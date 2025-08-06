from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import APIGateway
from diagrams.aws.compute import Lambda
from diagrams.aws.storage import S3
from diagrams.aws.ml import Rekognition
# Bedrockの専用アイコンがないため、汎用アイコンを利用
from diagrams.aws.general import General 
from diagrams.onprem.client import User, Client

# 図の全体設定
with Diagram("Oruby-drawing-helper", show=False, filename="aws_bedrock_agents_architecture", direction="LR"):

    # 外部ユーザー・フロントエンド
    user = User("ユーザー")
    with Cluster("フロントエンド"):
        ui = Client("React/Next.js\n画像アップロード画面")



    # AWS Cloud
    with Cluster("AWS Cloud"):
        
        api_gw = APIGateway("API Gateway\nRESTful API")
        
        lambda_func = Lambda("Lambda Function")

        with Cluster("ストレージ層"):
            s3_images = S3("S3 Bucket\nアップロード画像")
            s3_model = S3("S3 Bucket\n統計モデル")

        with Cluster("AI/ML層"):
            rekognition = Rekognition("Amazon Rekognition\n画像分析")
            
            with Cluster("Bedrock Multi-Agents"):
                agent1 = General("Bedrockエージェント\n(評価)\nClaude 3 Sonnet")
                agent2 = General("Bedrockエージェント\n(アドバイス)\nClaude 3 Sonnet")

    # データフローの定義
    user >> ui
    ui >> api_gw
    
    api_gw >> lambda_func
    
    lambda_func >> s3_images
    lambda_func >> rekognition
    rekognition >> lambda_func
    
    lambda_func << s3_model
    
    lambda_func >> agent1
    agent1 >> lambda_func

    lambda_func >> agent2
    agent2 >> lambda_func

    lambda_func >> api_gw
    api_gw >> ui
