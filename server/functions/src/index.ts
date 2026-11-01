import {setGlobalOptions} from "firebase-functions";

// 모든 함수를 서울 리전에 배포한다. maxInstances는 예상치 못한 트래픽에 대비한 함수별 컨테이너 상한이다.
setGlobalOptions({region: "asia-northeast3", maxInstances: 10});
